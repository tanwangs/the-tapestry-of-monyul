class_name NyeMap
extends Node2D
## Shared behaviour for the three nye maps.
##
## Places the student wherever the previous map handed them over, and clamps
## the camera to this map's size so the view never runs off the edge.

## The map's size in pixels; the camera is limited to this rectangle.
@export var map_size: Vector2 = Vector2(704, 416)
## Connected camera rooms within this same continuous trek scene.
@export var trek_rooms: Array[Rect2] = []
## A cinematic caption written across the curtain as this map is entered -
## the chapter title of a long hike. Empty for an ordinary fade-in arrival;
## skipped when a taxi brings the student in, because the taxi plays its own
## arrival moment at the rank.
@export var arrival_caption: String = ""
## How long the caption holds before the map is revealed.
@export var arrival_caption_hold: float = 2.0

@onready var _player: CharacterBody2D = $Player
var _active_room_index: int = -1


func _ready() -> void:
	# Each map asks the Music autoload for its own track; unmapped interiors
	# (the shrine, the dzong) keep the surrounding realm's music playing.
	Music.play_for_scene(scene_file_path, name)
	if Global.has_arrival_pos():
		_player.global_position = Global.take_arrival_pos()
	_restore_player_camera()
	_apply_camera_limits()
	_update_trek_camera_room()
	_clear_unclaimed_taxi_arrival()
	# Any menu from the map we came from is gone, and we arrive out of black.
	Global.ui_locked = false
	if _should_play_arrival_caption():
		_play_arrival_caption()
	else:
		ScreenFade.fade_in()


## The caption is the chapter title of a long hike on foot: the curtain
## closes on the map behind us, the caption is written across it for a while,
## and only then is the map revealed. A taxi arrival has its own arrival
## moment at the rank - the taxi driving in with the student aboard - so it
## takes a plain fade instead and hands the world back itself. The taxi's
## arrival is already underway here (the rank's _ready, which claims the trip,
## runs before this map's), so the still-hidden passenger marks it.
func _should_play_arrival_caption() -> bool:
	return not arrival_caption.is_empty() and not Global.taxi_passenger_hidden


func _play_arrival_caption() -> void:
	Global.ui_locked = true
	ScreenFade.fade_out(0.35)
	await get_tree().create_timer(0.45).timeout
	ScreenFade.show_message(arrival_caption, arrival_caption_hold, 0.5)
	await get_tree().create_timer(arrival_caption_hold + 0.8).timeout
	ScreenFade.fade_in()
	# No taxi arrival can be waiting: one would have skipped the caption and
	# taken the plain fade, handing the world back at its own stop.
	Global.ui_locked = false


## A taxi trip ends at the rank named by the hand-over; that rank claims the
## trip in its own _ready, which runs before this one. If it is still pending
## here the stop is missing, so the trip is dropped rather than left dangling
## to ambush a later scene.
func _clear_unclaimed_taxi_arrival() -> void:
	if not Global.taxi_arrival_pending:
		return
	push_warning("Taxi arrival pending, but no rank answers to '%s' in this scene." % Global.taxi_arrival_stop_path)
	Global.clear_taxi_arrival()


func _restore_player_camera() -> void:
	if _player == null:
		return
	var camera: Camera2D = _player.get_node_or_null("world_camera") as Camera2D
	if camera == null:
		return
	if camera.get_parent() != _player:
		camera.reparent(_player, false)
	camera.position = Vector2.ZERO
	camera.make_current()
	var artwork: CanvasItem = _player.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if artwork != null:
		artwork.visible = true


## Re-limits the shared camera, which is authored for the old world map.
func _apply_camera_limits() -> void:
	if _player == null:
		return
	var camera: Camera2D = _player.get_node_or_null("world_camera")
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)


func _physics_process(_delta: float) -> void:
	_update_trek_camera_room()


func _update_trek_camera_room() -> void:
	if trek_rooms.is_empty() or _player == null:
		return
	var player_position: Vector2 = _player.global_position
	for index: int in range(trek_rooms.size()):
		var room: Rect2 = trek_rooms[index]
		if room.has_point(player_position):
			if index != _active_room_index:
				_active_room_index = index
				_set_camera_room(room)
			return


func _set_camera_room(room: Rect2) -> void:
	var camera: Camera2D = _player.get_node_or_null("world_camera")
	if camera == null:
		return
	camera.limit_left = int(room.position.x)
	camera.limit_top = int(room.position.y)
	camera.limit_right = int(room.end.x)
	camera.limit_bottom = int(room.end.y)
