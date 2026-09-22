extends CanvasLayer
## Autoload singleton (Journal): the student's journal menu.
##
## Opened with the "open_menu" action (Tab or M) anywhere in the world. The
## journal is one dark-and-gold panel in the dialogue box's own look, with a
## header that shows the Connection Level and two tabs:
##
##   Quests          - every trackable quest the retreat can ask, split into
##                     a pending/active section and a completed section, each
##                     row reading its own state out of QuestLog/GameState.
##   Book of Memories - a gallery of the scenery cutscenes the realms leave
##                     behind. A finished realm's memory unlocks here the
##                     first time it plays, and can be rewatched any time.
##
## The journal never edits GameState; it only asks it questions, so the
## quest list is always true even when quests finish while it is open.

const GOLD: Color = Color(0.96, 0.78, 0.32)
const GOLD_DIM: Color = Color(0.85, 0.68, 0.27, 0.55)
const PARCHMENT: Color = Color(0.96, 0.93, 0.86)
const PARCHMENT_DIM: Color = Color(0.72, 0.68, 0.62)
const INK: Color = Color(0.12, 0.09, 0.08, 0.94)
const INK_LIT: Color = Color(0.21, 0.15, 0.08, 0.97)

const FRAME_SIZE: Vector2 = Vector2(880, 560)

var _root: Control
var _dim: ColorRect
var _frame: PanelContainer
var _connection_label: Label
var _quest_tab_button: Button
var _memory_tab_button: Button
var _content: ScrollContainer

var _tab: StringName = &"quests"
var _was_locked: bool = false


func _ready() -> void:
	layer = 60
	_build_ui()
	GameState.awareness_changed.connect(_on_awareness_changed)
	GameState.realm_completed.connect(func(_realm: StringName) -> void: _refresh_if_open())
	GameState.side_quest_completed.connect(func(_realm: StringName) -> void: _refresh_if_open())
	GameState.lore_recorded.connect(func(_key: StringName) -> void: _refresh_if_open())


## The journal's view of the Connection Level - the awareness the retreat
## grows in the student, written as a level.
func connection_text() -> String:
	return "Connection Level %d" % GameState.awareness


## True while the journal is on screen.
func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	_was_locked = Global.ui_locked
	Global.ui_locked = true
	_root.visible = true
	# The journal always opens on the quest list - the question "what is
	# being asked of me right now?" comes before the gallery. The Book of
	# Memories is a deliberate place to visit, and the tab keeps its look.
	_show_tab(&"quests")
	if _quest_tab_button != null:
		_quest_tab_button.grab_focus()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	if not _was_locked:
		Global.ui_locked = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_menu"):
			get_viewport().set_input_as_handled()
			close()
		return
	if event.is_action_pressed("open_menu"):
		if DialogueManager.is_active or Global.ui_locked or Memories.is_playing():
			return
		get_viewport().set_input_as_handled()
		open()


func _on_awareness_changed(_value: int) -> void:
	_refresh_if_open()


func _refresh_if_open() -> void:
	if not is_open():
		return
	_connection_label.text = connection_text()
	_show_tab(_tab)


# --- tabs ----------------------------------------------------------------

func _show_tab(tab: StringName) -> void:
	_tab = tab
	_style_tab(_quest_tab_button, tab == &"quests")
	_style_tab(_memory_tab_button, tab == &"memories")
	_connection_label.text = connection_text()
	_clear_content()
	match tab:
		&"quests":
			_build_quest_list()
		&"memories":
			_build_memory_gallery()


func _clear_content() -> void:
	# Off the tree at once, so a tab change or a GameState refresh never
	# leaves yesterday's list behind in the scroll for the rest of the frame
	# (a lore_recorded refresh can rebuild the tab several times in one step,
	# and queue_free alone would let every copy linger until frame's end).
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


# --- the Quests tab -------------------------------------------------------

func _build_quest_list() -> void:
	var list: VBoxContainer = _new_list_box()
	_content.add_child(list)

	var unfinished: Array[Dictionary] = QuestLog.open_quests()
	var done: Array[Dictionary] = QuestLog.completed_quests()

	list.add_child(_section_label("Pending & Active"))
	if unfinished.is_empty():
		list.add_child(_quiet_line("Nothing is being asked of the student right now."))
	for quest in unfinished:
		list.add_child(_quest_row(quest, false))

	list.add_child(_section_label("Completed"))
	if done.is_empty():
		list.add_child(_quiet_line("Nothing finished yet. The road east leads out of the village."))
	for quest in done:
		list.add_child(_quest_row(quest, true))


func _quest_row(quest: Dictionary, completed: bool) -> Control:
	var row: VBoxContainer = _new_row_box()
	row.add_child(_quest_title_line(quest, completed))

	var description: Label = Label.new()
	description.text = quest["description"]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 15)
	description.add_theme_color_override("font_color", PARCHMENT_DIM if completed else PARCHMENT)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(description)
	return row


func _quest_title_line(quest: Dictionary, completed: bool) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title: Label = Label.new()
	title.text = quest["title"]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GOLD_DIM if completed else GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(spacer)

	var state: Label = Label.new()
	if completed:
		state.text = "%s - done" % quest["place"]
		state.add_theme_color_override("font_color", GOLD_DIM)
	else:
		state.text = "%s - %s" % [quest["place"], _open_state_word(quest)]
		state.add_theme_color_override("font_color", PARCHMENT_DIM)
	state.add_theme_font_size_override("font_size", 14)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(state)
	return line


func _open_state_word(quest: Dictionary) -> String:
	if QuestLog.status_of(quest) == QuestLog.Status.PENDING:
		return "not yet asked"
	return "in progress"


# --- the Book of Memories tab ----------------------------------------------

func _build_memory_gallery() -> void:
	var list: VBoxContainer = _new_list_box()
	_content.add_child(list)

	var intro: Label = Label.new()
	intro.text = "Sceneries the retreat has left behind. Choose one to sit with it again."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 15)
	intro.add_theme_color_override("font_color", PARCHMENT_DIM)
	list.add_child(intro)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_child(row)

	for realm in Memories.REALM_ORDER:
		row.add_child(_memory_card(realm))


func _memory_card(realm: StringName) -> Button:
	var unlocked: bool = Memories.is_unlocked(realm)
	var card: Button = Button.new()
	card.flat = true
	card.custom_minimum_size = Vector2(256, 250)
	card.disabled = not unlocked
	card.pressed.connect(_on_memory_pressed.bind(realm))
	_style_button(card)
	if not unlocked:
		card.modulate = Color(0.55, 0.55, 0.55, 1.0)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)

	var picture: TextureRect = TextureRect.new()
	picture.texture = Memories.scenery_of(realm)
	picture.custom_minimum_size = Vector2(234, 132)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(picture)

	var title: Label = Label.new()
	title.text = Memories.title_of(realm) if unlocked else "Not yet remembered"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var state: Label = Label.new()
	state.text = "Rewatch" if unlocked else "The scenery will be kept here once the realm is finished."
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 13)
	state.add_theme_color_override("font_color", PARCHMENT_DIM)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(state)
	return card


func _on_memory_pressed(realm: StringName) -> void:
	close()
	Memories.play(realm)


# --- shared building blocks ------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Journal"
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.03, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_gui_input)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(center)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = FRAME_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = INK
	frame_style.border_width_left = 2
	frame_style.border_width_right = 2
	frame_style.border_width_top = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = GOLD_DIM
	frame_style.set_corner_radius_all(12)
	frame_style.content_margin_left = 24.0
	frame_style.content_margin_right = 24.0
	frame_style.content_margin_top = 20.0
	frame_style.content_margin_bottom = 16.0
	_frame.add_theme_stylebox_override("panel", frame_style)
	center.add_child(_frame)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	_frame.add_child(layout)

	layout.add_child(_build_header())

	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	layout.add_child(tab_row)
	_quest_tab_button = Button.new()
	_quest_tab_button.text = "  Quests  "
	_quest_tab_button.focus_mode = Control.FOCUS_ALL
	_quest_tab_button.pressed.connect(_show_tab.bind(&"quests"))
	tab_row.add_child(_quest_tab_button)
	_memory_tab_button = Button.new()
	_memory_tab_button.text = "  Book of Memories  "
	_memory_tab_button.focus_mode = Control.FOCUS_ALL
	_memory_tab_button.pressed.connect(_show_tab.bind(&"memories"))
	tab_row.add_child(_memory_tab_button)

	_content = ScrollContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(_content)

	var footer: Label = Label.new()
	footer.text = "Tab: journal        Esc: close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", PARCHMENT_DIM)
	layout.add_child(footer)


func _build_header() -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)

	var title: Label = Label.new()
	title.text = "The Student's Journal"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_connection_label = Label.new()
	_connection_label.text = connection_text()
	_connection_label.add_theme_font_size_override("font_size", 20)
	_connection_label.add_theme_color_override("font_color", PARCHMENT)
	header.add_child(_connection_label)
	return header


func _on_dim_gui_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventMouseButton and event.pressed:
		close()


func _section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", GOLD_DIM)
	return label


func _quiet_line(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", PARCHMENT_DIM)
	return label


func _new_list_box() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	return box


func _new_row_box() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	return box


## Gives a tab button its resting and raised looks.
func _style_tab(button: Button, active: bool) -> void:
	var idle: StyleBoxFlat = StyleBoxFlat.new()
	idle.bg_color = Color(0.16, 0.12, 0.10, 0.9) if active else Color(0.08, 0.06, 0.05, 0.75)
	idle.border_width_left = 2
	idle.border_width_right = 2
	idle.border_width_top = 2
	idle.border_width_bottom = 2
	idle.border_color = GOLD if active else GOLD_DIM
	idle.set_corner_radius_all(8)
	idle.content_margin_left = 14.0
	idle.content_margin_right = 14.0
	idle.content_margin_top = 6.0
	idle.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", idle)
	button.add_theme_stylebox_override("pressed", idle)
	button.add_theme_stylebox_override("focus", idle)
	var color: Color = GOLD if active else PARCHMENT_DIM
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)


## Gives a gallery card the same dark-and-gold look as the dialogue box.
func _style_button(button: Button) -> void:
	var idle: StyleBoxFlat = StyleBoxFlat.new()
	idle.bg_color = Color(0.12, 0.09, 0.08, 0.9)
	idle.border_width_left = 2
	idle.border_width_right = 2
	idle.border_width_top = 2
	idle.border_width_bottom = 2
	idle.border_color = GOLD_DIM
	idle.set_corner_radius_all(10)
	idle.content_margin_left = 10.0
	idle.content_margin_right = 10.0
	idle.content_margin_top = 10.0
	idle.content_margin_bottom = 10.0

	var lit: StyleBoxFlat = idle.duplicate()
	lit.bg_color = INK_LIT
	lit.border_color = GOLD

	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("focus", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("disabled", idle)
