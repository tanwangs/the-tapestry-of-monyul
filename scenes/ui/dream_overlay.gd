class_name DreamOverlay
extends CanvasLayer
## The full-screen dream that opens the retreat.
##
## The screen goes black, a picture fades up glowing, and a voice speaks one
## line at a time until the student presses on. Everything the world needs to
## do is wrapped up in the `finished` signal, so the village can carry on from
## there without knowing how the dream works.

## Emitted once the dream has faded away and control can be handed back.
signal finished

const FADE_IN_TIME: float = 1.3
const FADE_OUT_TIME: float = 1.0
const LINE_FADE: float = 0.7
## Nothing is accepted for this long, so a held key cannot skip the opening.
const ARM_DELAY: float = 0.6

@onready var _black: ColorRect = $Black
@onready var _center: Control = $Center
@onready var _glow: TextureRect = $Center/Layout/Picture/Glow
@onready var _tree: TextureRect = $Center/Layout/Picture/Tree
@onready var _voice: Label = $Center/Layout/Voice
@onready var _hint: Label = $Center/Layout/Hint

var _lines: Array[String] = []
var _index: int = 0
var _playing: bool = false
var _armed: bool = false


func _ready() -> void:
	visible = false
	_black.color.a = 1.0
	_center.modulate.a = 0.0


## Plays the dream. `picture` may be null for a text-only dream. Text of the
## form {player} is swapped for the student's name.
func play(lines: Array[String], picture: Texture2D) -> void:
	if lines.is_empty():
		finished.emit()
		return

	_lines.clear()
	for raw in lines:
		_lines.append(raw.replace("{player}", GameState.player_name))

	_index = 0
	_playing = true
	_armed = false
	visible = true
	Global.ui_locked = true

	_tree.texture = picture
	_glow.texture = picture
	_black.color.a = 1.0
	_center.modulate.a = 0.0
	_show_line()

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_center, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_property(_black, "color:a", 0.96, FADE_IN_TIME)

	_pulse_glow()
	await get_tree().create_timer(ARM_DELAY).timeout
	_armed = true


func _pulse_glow() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_glow, "modulate:a", 0.45, 1.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_glow, "modulate:a", 0.15, 1.7).set_trans(Tween.TRANS_SINE)


func _show_line() -> void:
	_voice.text = _lines[_index]
	_hint.text = "press  E  to go on" if _index < _lines.size() - 1 else "press  E  to wake"
	_voice.modulate.a = 0.0
	_hint.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_voice, "modulate:a", 1.0, LINE_FADE)
	tween.tween_property(_hint, "modulate:a", 1.0, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or not _armed:
		return
	if not (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		return

	get_viewport().set_input_as_handled()
	if _index < _lines.size() - 1:
		_index += 1
		_show_line()
	else:
		_end()


func _end() -> void:
	_playing = false
	_armed = false

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_center, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_property(_black, "color:a", 0.0, FADE_OUT_TIME)
	await tween.finished

	visible = false
	Global.ui_locked = false
	finished.emit()
