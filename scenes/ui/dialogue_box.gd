extends CanvasLayer
## The dialogue interface: a bottom-anchored panel that reveals each line one
## character at a time, then waits for the player to press talk again.
##
## The panel owns no story state. It listens to DialogueManager and draws
## whatever it is told, so nothing here needs changing when new conversations
## are written.

const CHARS_PER_SECOND: float = 45.0
## Seconds the "there is more" arrow stays on, and off, while it blinks.
const BLINK_ON: float = 0.55
## Where the box's top edge sits above its bottom anchor: its usual height,
## and the taller shape it takes while answer buttons are on screen.
const BOX_TOP_NORMAL: float = -220.0
const BOX_TOP_CHOICES: float = -340.0

@onready var _portrait_frame: PanelContainer = $Root/Frame/Layout/Top/PortraitFrame
@onready var _portrait: TextureRect = $Root/Frame/Layout/Top/PortraitFrame/Portrait
@onready var _speaker: Label = $Root/Frame/Layout/Top/Col/Speaker
@onready var _text: RichTextLabel = $Root/Frame/Layout/Top/Col/Text
@onready var _indicator: Label = $Root/Frame/Layout/Footer/Indicator

## The answer buttons for the line on screen, built when a line offers them.
var _choices_box: VBoxContainer
var _choice_buttons: Array[Button] = []

var _full_text: String = ""
var _revealed: float = 0.0
var _typing: bool = false
## False for the first frame of a conversation so the key press that opened the
## box cannot also skip its opening line.
var _accepts_input: bool = false
var _blink: float = 0.0


func _ready() -> void:
	visible = false
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.line_changed.connect(_on_line_changed)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	set_process(false)
	# The answer buttons live between the text and the continue arrow, so a
	# choice reads as part of the same conversation.
	_choices_box = VBoxContainer.new()
	_choices_box.name = "Choices"
	_choices_box.visible = false
	_choices_box.add_theme_constant_override("separation", 6)
	$Root/Frame/Layout.add_child(_choices_box)
	$Root/Frame/Layout.move_child(_choices_box, 1)


func _on_dialogue_started(_sequence: DialogueSequence) -> void:
	visible = true
	_accepts_input = false
	set_process(true)


func _on_line_changed(line: DialogueLine, _index: int) -> void:
	_speaker.text = line.speaker.replace("{player}", GameState.player_name)

	if line.portrait != null:
		_portrait.texture = line.portrait
		_portrait_frame.visible = true
	else:
		_portrait_frame.visible = false

	# {player} lets a line use the student's name without hard-coding it.
	_full_text = line.text.replace("{player}", GameState.player_name)
	_revealed = 0.0
	_typing = true
	_text.text = ""
	_indicator.visible = false
	_show_choices(line.choices)


func _on_dialogue_ended(_sequence: DialogueSequence) -> void:
	visible = false
	_typing = false
	_accepts_input = false
	_show_choices(PackedStringArray())
	set_process(false)


func _process(delta: float) -> void:
	_accepts_input = true

	if _typing:
		_revealed += CHARS_PER_SECOND * delta
		if _revealed >= float(_full_text.length()):
			_finish_revealing()
		else:
			_text.text = _full_text.substr(0, int(_revealed))
	elif not _choices_box.visible:
		_blink += delta
		_indicator.visible = fmod(_blink, BLINK_ON * 2.0) < BLINK_ON


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _accepts_input:
		return
	if not (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		return

	get_viewport().set_input_as_handled()
	if _typing:
		_finish_revealing()
	elif not _choices_box.visible:
		# While answers are on screen the buttons take the press instead.
		DialogueManager.advance()


## Drops the rest of the line in at once, and shows the continue arrow.
func _finish_revealing() -> void:
	_text.text = _full_text
	_revealed = float(_full_text.length())
	_typing = false
	_blink = 0.0
	_indicator.visible = not _choices_box.visible


## Shows one button per offered answer, or none for a plain spoken line.
## The first button takes keyboard focus, so the arrows and the talk key
## reach the answers without the mouse.
func _show_choices(options: PackedStringArray) -> void:
	for button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()
	_choices_box.visible = not options.is_empty()
	# The box grows while answers are on screen so they never crowd out the
	# text, and settles back once the conversation returns to plain lines.
	$Root.offset_top = BOX_TOP_CHOICES if not options.is_empty() else BOX_TOP_NORMAL
	if options.is_empty():
		return
	for i in options.size():
		var index: int = i
		var button: Button = Button.new()
		button.text = options[index]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86, 1))
		button.add_theme_color_override("font_hover_color", Color(0.96, 0.78, 0.32, 1))
		button.add_theme_color_override("font_focus_color", Color(0.96, 0.78, 0.32, 1))
		button.add_theme_color_override("font_pressed_color", Color(0.96, 0.78, 0.32, 1))
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_choice_pressed.bind(index))
		_choices_box.add_child(button)
		_choice_buttons.append(button)
	_choice_buttons[0].grab_focus()


## The player picked one of the answers; hand it to the conversation.
func _on_choice_pressed(index: int) -> void:
	DialogueManager.choose(index)
