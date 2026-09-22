class_name TravelMenu
extends CanvasLayer
## The taxi rank's destination picker.
##
## The buttons are built from whatever list the rank hands it, so a rank with
## one place to go and one with three need exactly the same code. Everything is
## mouse driven - the student clicks the icon of the place they want.

## Emitted with the index of the destination the student clicked.
signal destination_chosen(index: int)
## Emitted when the student backs out without choosing.
signal cancelled

@onready var _root: Control = $Root
@onready var _title: Label = $Root/Center/Frame/Layout/Title
@onready var _row: HBoxContainer = $Root/Center/Frame/Layout/Row
@onready var _preview: TextureRect = $Root/Center/Frame/Layout/Detail/DetailRow/Preview
@onready var _blurb: RichTextLabel = $Root/Center/Frame/Layout/Detail/DetailRow/Blurb

const DREAM_TREE: Texture2D = preload("res://assets/generated/pine_tree.png")

var _buttons: Array[Button] = []
var _destinations: Array[TravelDestination] = []
var _tree_hint: TextureRect = null
var _tree_flicker: Tween = null


func _ready() -> void:
	hide_menu()
	_root.gui_input.connect(_on_root_gui_input)


## Fills the row with one button per destination, then shows the menu.
func open(destinations: Array[TravelDestination], title: String) -> void:
	_clear()
	_title.text = title
	_destinations = destinations
	for i in destinations.size():
		_buttons.append(_make_button(destinations[i], i))

	visible = true
	Global.ui_locked = true
	if not _buttons.is_empty():
		_buttons[0].grab_focus()
		_show_detail(0)


## Closes the menu and hands control back to the world.
func hide_menu() -> void:
	visible = false
	Global.ui_locked = false
	_clear()


func _clear() -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()


func _make_button(destination: TravelDestination, index: int) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(150, 160)
	button.pressed.connect(_on_button_pressed.bind(index))
	button.focus_entered.connect(_show_detail.bind(index))
	button.mouse_entered.connect(_show_detail.bind(index))
	_style_button(button)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	button.add_child(column)

	var picture := TextureRect.new()
	picture.texture = destination.icon
	picture.custom_minimum_size = Vector2(84, 84)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(picture)

	var caption := Label.new()
	caption.text = destination.label
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	caption.add_theme_font_size_override("font_size", 16)
	column.add_child(caption)

	_row.add_child(button)
	return button


## Gives a button the same dark-and-gold look as the dialogue box.
func _style_button(button: Button) -> void:
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0.12, 0.09, 0.08, 0.9)
	idle.border_width_left = 2
	idle.border_width_right = 2
	idle.border_width_top = 2
	idle.border_width_bottom = 2
	idle.border_color = Color(0.85, 0.68, 0.27, 0.35)
	idle.set_corner_radius_all(10)
	idle.content_margin_left = 12.0
	idle.content_margin_right = 12.0
	idle.content_margin_top = 12.0
	idle.content_margin_bottom = 12.0

	var lit: StyleBoxFlat = idle.duplicate()
	lit.bg_color = Color(0.21, 0.15, 0.08, 0.95)
	lit.border_color = Color(0.96, 0.78, 0.32, 1.0)

	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("focus", lit)
	button.add_theme_stylebox_override("pressed", lit)


## Shows the highlighted destination's picture and flavour text.
func _show_detail(index: int) -> void:
	if index < 0 or index >= _destinations.size():
		return
	var destination: TravelDestination = _destinations[index]
	_preview.texture = destination.icon
	_blurb.text = destination.blurb if destination.blurb != "" else destination.label
	_flicker_tree_hint()


func _flicker_tree_hint() -> void:
	if _tree_hint == null:
		_tree_hint = TextureRect.new()
		_tree_hint.texture = DREAM_TREE
		_tree_hint.custom_minimum_size = Vector2(48, 48)
		_tree_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tree_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tree_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tree_hint.modulate = Color(0.74, 0.84, 1.0, 0.0)
		_blurb.get_parent().add_child(_tree_hint)
	if _tree_flicker != null and _tree_flicker.is_valid():
		_tree_flicker.kill()
	_tree_flicker = create_tween()
	_tree_flicker.tween_property(_tree_hint, "modulate:a", 0.52, 0.12)
	_tree_flicker.tween_property(_tree_hint, "modulate:a", 0.12, 0.16)
	_tree_flicker.tween_property(_tree_hint, "modulate:a", 0.42, 0.12)
	_tree_flicker.tween_property(_tree_hint, "modulate:a", 0.0, 0.25)


func _on_button_pressed(index: int) -> void:
	hide_menu()
	destination_chosen.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()


## A click that misses every button means "not right now".
func _on_root_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		_dismiss()


func _dismiss() -> void:
	hide_menu()
	cancelled.emit()
