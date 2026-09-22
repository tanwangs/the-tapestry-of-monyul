extends Node
## Autoload (Music) that owns every background track in the game.
##
## One place to switch scene music: a scene asks for its track and the autoload
## crossfades from whatever is playing to it, so no scene needs its own
## AudioStreamPlayer or fade logic. Asking for the track that is already playing
## does nothing, so re-entering a scene never restarts its music.
##
## The autoload persists across scene changes, so a taxi ride keeps the
## departure scene's music playing through the journey; the destination scene
## asks for its own track on load and the crossfade happens there, under the
## arrival curtain.

## The dream track - shared by the opening dream and the ending dream, so the
## two moments keep one sonic identity - and, the tutorial track being
## retired, also the village's own background music.
const DREAM: AudioStream = preload("res://assets/audio/music/dream.mp3")
## The crossroads / lobby track.
const LOBBY: AudioStream = preload("res://assets/audio/music/lobby.wav")
## The three realm tracks.
const JOMOLHARI: AudioStream = preload("res://assets/audio/music/jomolhari.wav")
const DRAKAY_PANGTSHO: AudioStream = preload("res://assets/audio/music/drakeypangtsho.wav")
const TAKTSANG: AudioStream = preload("res://assets/audio/music/taktsang.wav")

## Which track each nye map plays, keyed by scene file. Interior rooms (the
## shrine, the dzong) are deliberately unmapped so they keep the surrounding
## realm's track playing instead of going quiet or restarting it.
const TRACK_BY_SCENE_FILE: Dictionary = {
	"res://scenes/nyes/jhomo_lhari.tscn": JOMOLHARI,
	"res://scenes/nyes/drakay_pangtsho.tscn": DRAKAY_PANGTSHO,
	"res://scenes/nyes/tak_tsang.tscn": TAKTSANG,
}

## The same mapping keyed by root node name, so the right track still plays
## even when the map is instanced rather than loaded as the main scene.
const TRACK_BY_ROOT_NAME: Dictionary = {
	"JhomoLhari": JOMOLHARI,
	"DrakayPangtsho": DRAKAY_PANGTSHO,
	"TakTsang": TAKTSANG,
}

## The volume a fully-faded-in track sits at.
const FULL_DB: float = 0.0
## Quiet enough to be inaudible; fades start and end at this.
const SILENT_DB: float = -60.0

## Every provided track was authored with a fade-out at the end followed by a
## pad of silence (up to ~7 s of it). Looping the raw file would breathe a
## silent dip into the ambience on every repeat, so the loop points are pulled
## in to the last audible sample on the WAVs - a playback-side trim, the files
## themselves are untouched. Measured from the source waveforms:
## Vector2i(loop_begin, loop_end) in samples at the file's mix rate.
const LOOP_POINTS_BY_FILE: Dictionary = {
	"res://assets/audio/music/drakeypangtsho.wav": Vector2i(124, 6768944),
	"res://assets/audio/music/jomolhari.wav": Vector2i(37, 7110337),
	"res://assets/audio/music/lobby.wav": Vector2i(32, 6912229),
	"res://assets/audio/music/taktsang.wav": Vector2i(6689, 4635586),
}

## Ogg Vorbis and MP3 only support a loop *begin* offset, not a loop end, so
## their trailing silence cannot be trimmed away at playback time; only the
## leading pad is skipped, in seconds. dream.mp3 carries ~0.6 s of lead-in.
const LOOP_OFFSET_BY_FILE: Dictionary = {
	"res://assets/audio/music/dream.mp3": 0.595,
}

## The track currently playing (or fading in); null when silent.
var _current: AudioStream = null
## The player the current track lives in. Always exists, but may be idle.
var _active: AudioStreamPlayer
## Players fading out before they free themselves.
var _dying: Array[AudioStreamPlayer] = []
## The fade tween each live player is riding, so a hard stop can kill it.
var _fade_tweens: Dictionary = {}
## Keeps spawned player names unique.
var _player_count: int = 0


func _ready() -> void:
	# Nothing in this game pauses the whole tree, but if that ever changes the
	# music should keep breathing through it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active = _new_player(null)


func _exit_tree() -> void:
	# The engine is about to tear down; let the tracks go so nothing is left
	# holding a stream when the leftover resources are checked.
	silence_now()


## Crossfades from whatever is playing to `stream` over `fade_duration`: the old
## player fades out while the new one fades in. Asking for the track that is
## already playing does nothing. A null stream fades to silence.
func play_track(stream: AudioStream, fade_duration: float = 1.0) -> void:
	if stream == null:
		stop_track(fade_duration)
		return
	if stream == _current:
		# Re-entering a scene, or two calls for the same track: no restart.
		return
	_ensure_loop(stream)
	if _current != null:
		_retire(_active, fade_duration)
	_current = stream
	_active = _new_player(stream)
	_active.volume_db = SILENT_DB
	if not _headless():
		_active.play()
	_fade_volume(_active, FULL_DB, fade_duration)


## Fades whatever is playing down to silence over `fade_duration`.
func stop_track(fade_duration: float = 1.0) -> void:
	if _current == null:
		return
	_current = null
	_retire(_active, fade_duration)
	_active = _new_player(null)


## The player the current track is loaded into; mainly so tests can inspect the
## hand-off between tracks.
func active_player() -> AudioStreamPlayer:
	return _active


## A headless run (the test harness) has no audio driver that ever drains a
## started playback, which pins the stream for the rest of the process - so no
## playback is started there at all. The game always runs with a real driver.
func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Stops every player at once and discards any fades still in flight. The
## tests tear down between frames those fades would have needed.
func silence_now() -> void:
	_current = null
	var players: Array[AudioStreamPlayer] = []
	for child in get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null:
			players.append(player)
	for player in players:
		_kill_fade(player)
		player.stop()
		player.stream = null
		player.free()
	_dying.clear()
	_active = _new_player(null)


## Plays the track mapped to a scene, if there is one. Unmapped scenes - the
## shrine rooms and the dzong interiors - keep whatever is playing, so they
## share their realm's music.
func play_for_scene(scene_path: String, root_name: String = "") -> void:
	var track: AudioStream = TRACK_BY_SCENE_FILE.get(scene_path)
	if track == null and root_name != "":
		track = TRACK_BY_ROOT_NAME.get(root_name)
	if track == null:
		return
	play_track(track)


## The track currently playing (or fading in), or null in silence.
func current_track() -> AudioStream:
	return _current


## Background music loops, so the one-shot defaults baked into the import
## files are overridden here rather than by hand-editing .import files. For Ogg
## and MP3 this is a plain `loop` flag plus a begin offset; WAV needs a forward
## loop mode and takes the measured loop points above, which trim the authored
## fade-out and trailing silence out of the loop.
func _ensure_loop(stream: AudioStream) -> void:
	var path: String = stream.resource_path
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
		stream.loop_offset = LOOP_OFFSET_BY_FILE.get(path, 0.0)
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var points: Vector2i = LOOP_POINTS_BY_FILE.get(path, Vector2i(0, -1))
		stream.loop_begin = points.x
		if points.y >= 0:
			# Clamped to whatever the import actually produced.
			stream.loop_end = mini(points.y, int(stream.get_length() * stream.mix_rate) - 1)


## Hands the player to the fading-out pile; it stops and frees itself once the
## fade lands.
func _retire(player: AudioStreamPlayer, fade_duration: float) -> void:
	_dying.append(player)
	if _headless():
		# Nothing is actually sounding, so there is nothing to fade: release
		# the track at once rather than pinning it to a deferred frame.
		_finish_dying(player)
		return
	_fade_volume(player, SILENT_DB, fade_duration, true)


func _fade_volume(player: AudioStreamPlayer, to_db: float, fade_duration: float, stop_after: bool = false) -> void:
	if fade_duration <= 0.01:
		player.volume_db = to_db
		if stop_after:
			_finish_dying(player)
		return
	var tween: Tween = create_tween()
	# Whatever fade this player was already riding is over; two tweens would
	# fight over the same volume and the loser's callback would find it freed.
	_kill_fade(player)
	_fade_tweens[player] = tween
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "volume_db", to_db, fade_duration)
	if stop_after:
		tween.tween_callback(_finish_dying.bind(player))
	else:
		tween.finished.connect(func() -> void: _fade_tweens.erase(player))


func _kill_fade(player: AudioStreamPlayer) -> void:
	var tween: Tween = _fade_tweens.get(player)
	if tween != null and tween.is_valid():
		tween.kill()
	_fade_tweens.erase(player)


func _finish_dying(player: AudioStreamPlayer) -> void:
	_dying.erase(player)
	_kill_fade(player)
	player.stop()
	player.queue_free()


func _new_player(stream: AudioStream) -> AudioStreamPlayer:
	_player_count += 1
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "Track%d" % _player_count
	player.stream = stream
	add_child(player)
	return player
