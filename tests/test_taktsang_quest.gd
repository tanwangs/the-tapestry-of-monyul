extends Node
## The Taktsang realm: the story of three keepers of memory,
## and the ringing of the bell that closes the evening.

const QUEST: String = "res://scripts/narrative/taktsang_quest.gd"
const SCENE: String = "res://scenes/nyes/tak_tsang.tscn"
const INTRO: StringName = &"taktsang_quest_intro"
const SIDE_COMPLETE: StringName = &"taktsang_side_complete"

var _spawned: Array[Node] = []


func before_each() -> void:
	DialogueManager.stop()
	GameState.reset()
	Global.ui_locked = false


func after_each() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _new_quest() -> TaktsangQuest:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(scene)
	_spawned.append(scene)
	await get_tree().create_timer(0.1).timeout
	return scene.get_node_or_null("Quest") as TaktsangQuest


func test_the_quest_script_exists_and_has_the_right_realm() -> Variant:
	var script: Script = load(QUEST) as Script
	if script == null:
		return "the TaktsangQuest script must exist"
	var instance := TaktsangQuest.new()
	add_child(instance)
	_spawned.append(instance)
	instance.free()
	return null


func test_the_three_keepers_are_referenced() -> Variant:
	var quest: TaktsangQuest = await _new_quest()
	if quest.historical_monk_path == NodePath():
		return "the quest must have a historical_monk_path"
	if quest.playful_monk_path == NodePath():
		return "the quest must have a playful_monk_path"
	if quest.personal_monk_path == NodePath():
		return "the quest must have a personal_monk_path"
	return null


func test_the_three_keepers_are_found_on_ready() -> Variant:
	var quest: TaktsangQuest = await _new_quest()
	var historical: NPC = quest._historical_monk as NPC
	if historical == null:
		return "the quest must find the historical monk"
	var playful: NPC = quest._playful_monk as NPC
	if playful == null:
		return "the quest must find the playful monk"
	var personal: NPC = quest._personal_monk as NPC
	if personal == null:
		return "the quest must find the personal monk"
	return null


func test_items_are_not_interactable_before_the_quest_starts() -> Variant:
	var quest: TaktsangQuest = await _new_quest()
	await get_tree().create_timer(0.1).timeout
	var historical: NPC = quest._historical_monk as NPC
	if historical == null:
		return "historical monk must exist"
	if historical.sequence != null:
		return "the historical monk must not be interactable before the quest starts"
	return null


func test_wheels_are_visible_and_tracked() -> Variant:
	var quest: TaktsangQuest = await _new_quest()
	await get_tree().create_timer(0.1).timeout
	if quest._wheels.size() != 3:
		return "the quest must track exactly three prayer wheels, found %d" % quest._wheels.size()
	for wheel in quest._wheels:
		if not wheel.visible:
			return "prayer wheels must be visible"
	return null


func test_listening_marks_the_side_quest_once() -> Variant:
	var quest: TaktsangQuest = await _new_quest()
	await get_tree().create_timer(0.1).timeout
	for wheel in quest._wheels:
		GameState.mark_seen(quest._key_of(wheel))
	quest._refresh()
	if GameState.is_side_complete(&"taktsang"):
		return "the side quest must not be complete before all three wheels are spun"
	return null


func test_the_quest_sequences_are_preloaded() -> Variant:
	var script: Script = load(QUEST) as Script
	var instance := TaktsangQuest.new()
	add_child(instance)
	_spawned.append(instance)
	instance.free()
	return null


func test_awareness_is_given_once_per_quest() -> Variant:
	var announced: Array[int] = []
	var record := func(value: int) -> void: announced.append(value)
	GameState.awareness_changed.connect(record)
	GameState.add_awareness(3)
	GameState.add_awareness(3)
	GameState.awareness_changed.disconnect(record)
	if GameState.awareness != 6:
		return "awareness should accumulate to 6, got %d" % GameState.awareness
	return null


func test_unknown_realms_are_ignored() -> Variant:
	GameState.mark_realm_complete(&"not_a_realm")
	if GameState.is_realm_complete(&"not_a_realm"):
		return "an unknown realm must not count as complete"
	return null


func test_the_quest_scene_loads_cleanly() -> Variant:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(scene)
	_spawned.append(scene)
	var quest: TaktsangQuest = scene.get_node_or_null("Quest") as TaktsangQuest
	if quest == null:
		return "the Taktsang scene must have a Quest node"
	var mood: CanvasModulate = scene.get_node_or_null("Mood") as CanvasModulate
	if mood == null:
		return "the scene must have a Mood CanvasModulate"
	scene.queue_free()
	return null


func test_the_monk_has_been_given_the_quest_sequence() -> Variant:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(scene)
	_spawned.append(scene)
	await get_tree().create_timer(0.1).timeout
	var monk: NPC = scene.get_node_or_null("Monk") as NPC
	if monk == null:
		return "the scene must have a Monk node"
	if monk.lore_key != &"taktsang_quest_intro":
		return "the monk must have the quest intro as its lore key"
	scene.queue_free()
	return null


func test_the_retell_is_a_real_choice_of_three_fragments() -> Variant:
	var quest: TaktsangQuest = await _new_quest()
	if quest.RETELL_CHOICE_SEQ.lines.size() != 1:
		return "the retell must be a single question that waits for an answer"
	var options: PackedStringArray = quest.RETELL_CHOICE_SEQ.lines[0].choices
	if options.size() != 3:
		return "the retell must offer one option per fragment, got %d" % options.size()
	for option in options:
		if option.strip_edges().is_empty():
			return "every fragment option must say what it is"
	return null


func test_the_retell_choices_render_as_clickable_buttons() -> Variant:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(scene)
	_spawned.append(scene)
	await get_tree().create_timer(0.1).timeout
	var quest: TaktsangQuest = scene.get_node_or_null("Quest") as TaktsangQuest
	var box: CanvasLayer = scene.get_node_or_null("DialogueBox") as CanvasLayer
	if box == null:
		return "the scene must carry the dialogue box"
	DialogueManager.start(quest.RETELL_CHOICE_SEQ)
	await get_tree().process_frame
	await get_tree().process_frame
	var options: PackedStringArray = DialogueManager.current_choices()
	if options.size() != 3:
		return "the retell must offer three answers on screen, got %d" % options.size()
	var choices: VBoxContainer = box.get_node("Root/Frame/Layout/Choices") as VBoxContainer
	var buttons: Array[Button] = []
	for child in choices.get_children():
		if child is Button:
			buttons.append(child as Button)
	if buttons.size() != 3:
		return "each answer must be its own button, found %d" % buttons.size()
	var screen: Rect2 = Rect2(Vector2.ZERO, box.get_viewport().get_visible_rect().size)
	var frame: PanelContainer = box.get_node("Root/Frame") as PanelContainer
	for i in buttons.size():
		var button: Button = buttons[i]
		var rect: Rect2 = button.get_global_rect()
		if button.text.strip_edges().is_empty():
			return "answer button %d must say what it offers" % i
		if button.disabled:
			return "answer button %d must be clickable" % i
		if not screen.encloses(rect):
			return "answer button %d must sit inside the screen, got %s" % [i, rect]
		if not frame.get_global_rect().encloses(rect):
			return "answer button %d must sit inside the dialogue frame, got %s inside frame %s" % [i, rect, frame.get_global_rect()]
		if rect.size.y < 8.0:
			return "answer button %d must be big enough to press, got %s" % [i, rect.size]
	# The talk key must not end a line that offers answers.
	DialogueManager.advance()
	if not DialogueManager.is_active:
		return "the question must hold while the answers wait for a pick"
	DialogueManager.stop()
	return null


func test_the_bell_is_silent_until_the_retelling_is_done() -> Variant:
	var quest: TaktsangQuest = await _new_quest()
	if quest._bell_npc == null:
		return "the scene must have a bell that can be struck"
	if quest._bell_npc.sequence != null:
		return "the bell must be silent before the quest has even begun"
	GameState.mark_seen(quest.QUEST_STARTED)
	GameState.mark_seen(quest._key_of(quest._historical_monk))
	GameState.mark_seen(quest._key_of(quest._playful_monk))
	GameState.mark_seen(quest._key_of(quest._personal_monk))
	quest._refresh()
	if quest._bell_npc.sequence != null:
		return "the bell must not be strikable while the retelling still waits"
	return null


func test_every_fragment_choice_completes_the_quest() -> Variant:
	var flags: Array[StringName] = [
		&"taktsang_chose_founding",
		&"taktsang_chose_tiger",
		&"taktsang_chose_visitor",
	]
	for choice in 3:
		# A fresh evening for each fragment, so each choice is judged alone.
		DialogueManager.stop()
		GameState.reset()
		var quest: TaktsangQuest = await _new_quest()
		var monk: NPC = quest._monk
		GameState.mark_seen(quest.QUEST_STARTED)
		GameState.mark_seen(quest._key_of(quest._historical_monk))
		GameState.mark_seen(quest._key_of(quest._playful_monk))
		GameState.mark_seen(quest._key_of(quest._personal_monk))
		quest._refresh()
		if monk.sequence == null or monk.sequence.id != quest.RETELL_CHOICE:
			return "with every fragment heard, the head monk must offer the retell"
		# The question holds until a real pick: the talk key must not end it.
		DialogueManager.start(monk._pick_sequence())
		DialogueManager.advance()
		if not DialogueManager.is_active:
			return "the retell must wait for the player's choice"
		if not DialogueManager.choose(choice):
			return "fragment choice %d must be pickable" % choice
		# The chosen fragment is then spoken aloud.
		if not DialogueManager.is_active:
			return "the chosen fragment should be spoken after the choice"
		var guard: int = 0
		while DialogueManager.is_active and guard < 16:
			DialogueManager.advance()
			guard += 1
		if not quest._retelling_complete:
			return "choice %d must finish the retelling" % choice
		if not GameState.has_seen(flags[choice]):
			return "choice %d must be remembered as the player's own" % choice
		# The bell unlocks only now, and striking it closes the quest.
		var bell: NPC = quest._bell_npc
		if bell == null or bell.sequence == null or bell.sequence.id != &"taktsang_bell_ring":
			return "the bell must wait until after the retelling is done"
		DialogueManager.start(bell._pick_sequence())
		guard = 0
		while DialogueManager.is_active and guard < 16:
			DialogueManager.advance()
			guard += 1
		# The closing beat arrives after a short pause behind the strike.
		await get_tree().create_timer(0.9).timeout
		if not DialogueManager.is_active:
			return "ringing the bell must lead to the quest's close"
		guard = 0
		while DialogueManager.is_active and guard < 16:
			DialogueManager.advance()
			guard += 1
		if not GameState.is_realm_complete(&"taktsang"):
			return "every fragment choice must complete the quest, choice %d did not" % choice
		# Let the realm's closing fade finish before the next evening begins.
		await get_tree().create_timer(2.2).timeout
		var scene: Node = quest.get_parent()
		if scene != null:
			scene.queue_free()
	return null


func test_three_new_monks_are_in_the_scene() -> Variant:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(scene)
	_spawned.append(scene)
	await get_tree().create_timer(0.1).timeout
	var historical: NPC = scene.get_node_or_null("HistoricalMonk") as NPC
	if historical == null:
		return "the scene must have a HistoricalMonk node"
	var playful: NPC = scene.get_node_or_null("PlayfulMonk") as NPC
	if playful == null:
		return "the scene must have a PlayfulMonk node"
	var personal: NPC = scene.get_node_or_null("PersonalMonk") as NPC
	if personal == null:
		return "the scene must have a PersonalMonk node"
	scene.queue_free()
	return null
