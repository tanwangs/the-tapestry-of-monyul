extends CanvasLayer
## Autoload singleton (Memories): the scenery cutscenes, and the book that
## keeps them.
##
## A "memory" is a full-screen scenery painting with a title and a line of
## caption - the view a realm leaves behind when its quest is finished. The
## first time a realm completes, its memory is unlocked in GameState and the
## cutscene plays over the map; from then on it can be rewatched any time
## from the journal's Book of Memories.
##
## The beat ordering is deliberate: a realm's own closing moment - the bell,
## the brightening water - belongs to the map, so the memory only rises once
## that moment has had its breath of quiet.

## Emitted the first time a realm's memory is unlocked.
signal memory_unlocked(realm: StringName)
## Emitted when a scenery cutscene begins playing.
signal memory_started(realm: StringName)
## Emitted when a scenery cutscene is over, whatever ended it.
signal memory_finished(realm: StringName)

## Where the memory's GameState key lives, so the unlock survives scene
## changes the same way every other piece of the story does.
static func memory_key(realm: StringName) -> StringName:
	return StringName("memory_" + String(realm))

## The memories the book keeps, in the order the trek visits them.
const REALM_ORDER: Array[StringName] = [&"drakay_pangtsho", &"taktsang", &"jomolhari"]

const SCENERY: Dictionary = {
	&"jomolhari": {
		"title": "Jhomolhari",
		"caption": "The mountain of the goddess - ice, stone, and a silence you can hear.",
		"image": preload("res://assets/generated/scenery_jomolhari.png"),
	},
	&"taktsang": {
		"title": "Taktsang",
		"caption": "The tiger's nest holds to the cliff, and the evening bell carries down the valley.",
		"image": preload("res://assets/generated/scenery_taktsang.png"),
	},
	&"drakay_pangtsho": {
		"title": "Drakay Pangtsho",
		"caption": "The lake lies clear again, holding the sky the way the valley holds its water.",
		"image": preload("res://assets/generated/scenery_drakay_pangtsho.png"),
	},
}

## The pause between a realm's closing beat and its memory rising.
const REALM_BEAT_QUIET_S: float = 2.2
## How long the scenery holds before it puts itself away.
const VIEW_HOLD_S: float = 4.5
const FADE_IN_S: float = 0.7
const FADE_OUT_S: float = 0.9

## Whether finishing a realm plays its memory over the map. Off in headless
## runs, where the test suite completes realms constantly and the cutscene
## would lock the world between tests; tests turn it back on to verify it.
var autoplay: bool = false

var _root: Control
var _picture: TextureRect
var _title: Label
var _caption: Label
var _hint: Label
var _playing: bool = false
var _current: StringName = &""
var _skip_requested: bool = false


func _ready() -> void:
	layer = 90
	autoplay = DisplayServer.get_name() != "headless"
	_build_ui()
	GameState.realm_completed.connect(_on_realm_completed)


## True while a scenery cutscene is on screen.
func is_playing() -> bool:
	return _playing


## Which memory is on screen right now, or an empty name.
func current_memory() -> StringName:
	return _current


## True when the book holds an unlocked memory for this realm.
func is_unlocked(realm: StringName) -> bool:
	return GameState.has_seen(memory_key(realm))


## The scenery painting of a memory, for the journal's gallery cards.
func scenery_of(realm: StringName) -> Texture2D:
	var entry: Dictionary = SCENERY.get(realm, {})
	return entry.get("image") as Texture2D


## The written title and caption of a memory, for the gallery cards.
func title_of(realm: StringName) -> String:
	return SCENERY[realm]["title"]


func caption_of(realm: StringName) -> String:
	return SCENERY[realm]["caption"]


## Records a memory in the book. Returns false when there is no such memory
## or it was unlocked already.
func unlock(realm: StringName) -> bool:
	if not SCENERY.has(realm) or is_unlocked(realm):
		return false
	GameState.mark_seen(memory_key(realm))
	memory_unlocked.emit(realm)
	return true


## Plays a scenery cutscene. Returns false when there is no such memory, it
## is still locked in the book, or one is already on screen. Control is
## taken for the duration and handed back afterwards - unless it was already
## taken, in which case it stays so.
func play(realm: StringName) -> bool:
	if _playing or not SCENERY.has(realm) or not is_unlocked(realm):
		return false
	_playing = true
	_current = realm
	_skip_requested = false
	var was_locked: bool = Global.ui_locked
	Global.ui_locked = true

	var entry: Dictionary = SCENERY[realm]
	_picture.texture = entry["image"]
	_title.text = entry["title"]
	_caption.text = entry["caption"]
	_root.modulate.a = 0.0
	_root.visible = true
	memory_started.emit(realm)

	var fade_in: Tween = create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, FADE_IN_S)
	await _await_view(fade_in)

	await _hold(VIEW_HOLD_S)

	var fade_out: Tween = create_tween()
	fade_out.tween_property(_root, "modulate:a", 0.0, FADE_OUT_S)
	await _await_view(fade_out)
	_root.visible = false

	_playing = false
	_current = &""
	if not was_locked:
		Global.ui_locked = false
	memory_finished.emit(realm)
	return true


## A realm has finished its quest: unlock the memory, then - in a live game -
## let the realm's own closing beat have its quiet before the scenery rises.
func _on_realm_completed(realm: StringName) -> void:
	unlock(realm)
	if not autoplay:
		return
	await get_tree().create_timer(REALM_BEAT_QUIET_S).timeout
	if not is_inside_tree():
		return
	while DialogueManager.is_active or Global.ui_locked:
		await get_tree().create_timer(0.3).timeout
		if not is_inside_tree():
			return
	play(realm)


func _await_view(tween: Tween) -> void:
	# The fade itself can be cut short with the talk key, like the hold.
	while tween.is_valid():
		if _skip_requested:
			tween.kill()
			_root.modulate.a = 1.0
			return
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds and not _skip_requested:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1


## Ends the scenery on screen at the next breath. Safe to call any time.
func request_skip() -> void:
	if _playing:
		_skip_requested = true


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		request_skip()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Scenery"
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.04)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_picture)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 8)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 36.0
	_root.add_child(_title)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_top = -84.0
	_caption.offset_bottom = -48.0
	_caption.offset_left = -420.0
	_caption.offset_right = 420.0
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(_caption)

	_hint = Label.new()
	_hint.text = "E: continue"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1, 1, 1, 0.0)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -140.0
	_hint.offset_top = -34.0
	_root.add_child(_hint)
	# The hint only appears once the scenery has settled, so it never
	# competes with the title for the first glance.
	var hint_fade: Tween = create_tween().set_loops()
	hint_fade.tween_interval(FADE_IN_S + 0.6)
	hint_fade.tween_property(_hint, "modulate:a", 0.55, 0.4)
	hint_fade.tween_interval(3.0)
	hint_fade.tween_property(_hint, "modulate:a", 0.0, 0.4)
