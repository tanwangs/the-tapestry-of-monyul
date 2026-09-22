extends Node
## The Jomolhari realm: the offering at Tsheringma Ney, and the pacing
## gate that makes the ritual a real one rather than a mash of buttons.
##
## Each test states one behaviour the rest of the game relies on.

const QUEST: String = "res://scripts/narrative/jomolhari_quest.gd"
const SCENE: String = "res://scenes/nyes/jhomo_lhari.tscn"
const RUSH_INTERRUPT: String = "Again. Slower."
const JOMO_ANSWER: String = "Better."
## Well above the 650ms minimum the gate enforces between presses.
const DELIBERATE_PAUSE: float = 0.8

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


func _new_scene() -> Node:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(scene)
	_spawned.append(scene)
	return scene


## A scene with the quest underway and all three offerings gathered: the
## state a student reaches by walking the ledge and picking things up.
## Returns [scene, quest, altar, error-message].
func _ready_scene_with_offering() -> Array:
	var scene: Node = _new_scene()
	await get_tree().create_timer(0.1).timeout
	var quest: JomolhariQuest = scene.get_node_or_null("Quest") as JomolhariQuest
	if quest == null:
		return [null, null, null, "the Jhomo Lhari scene must have a Quest node"]
	GameState.mark_seen(quest.QUEST_STARTED)
	for item in quest._items:
		GameState.mark_seen(quest._key_of(item))
	quest._refresh()
	var altar: NPC = scene.get_node_or_null("TsheringmaNey") as NPC
	if altar == null:
		return [null, null, null, "the scene must have the Tsheringma Ney altar"]
	return [scene, quest, altar, ""]


## Walks one full offering conversation, pausing between every press.
func _offer_deliberately(altar: NPC) -> void:
	DialogueManager.start(altar.sequence)
	for i: int in range(altar.sequence.lines.size()):
		await get_tree().create_timer(DELIBERATE_PAUSE).timeout
		DialogueManager.advance()


func test_the_quest_script_exists_and_has_the_right_realm() -> Variant:
	var script: Script = load(QUEST) as Script
	if script == null:
		return "the JomolhariQuest script must exist"
	var instance: JomolhariQuest = JomolhariQuest.new()
	add_child(instance)
	_spawned.append(instance)
	instance.free()
	return null


func test_the_altar_offers_the_offering_once_everything_is_held() -> Variant:
	var result: Array = await _ready_scene_with_offering()
	var altar: NPC = result[2]
	if result[3] != "":
		return result[3]
	if altar.sequence == null or altar.sequence.id != &"jhomo_altar_offering":
		return "the altar must offer the offering sequence once all three items are held"
	return null


func test_mashing_the_offering_is_interrupted_and_completes_nothing() -> Variant:
	var result: Array = await _ready_scene_with_offering()
	var altar: NPC = result[2]
	if result[3] != "":
		return result[3]

	# Begin the ritual, then mash: the very next press lands far inside the
	# minimum interval the gate enforces.
	DialogueManager.start(altar.sequence)
	DialogueManager.advance()

	# The gate should have cut the ritual short and put Aum Jomo's line on
	# screen instead of letting the mashing carry on to the end.
	if GameState.is_realm_complete(&"jomolhari"):
		return "a mashed offering must not complete the realm"
	if not DialogueManager.is_active:
		return "the rush interrupt should be on screen after mashing"
	var line: DialogueLine = DialogueManager.current_line
	if line == null:
		return "the rush interrupt should be speaking"
	if line.speaker != "Aum Jomo" or line.text != RUSH_INTERRUPT:
		return "the interrupt must be Aum Jomo saying '%s', got '%s: %s'" % [
			RUSH_INTERRUPT, line.speaker, line.text
		]
	if GameState.awareness != 0:
		return "a rushed offering must grant no understanding, got %d" % GameState.awareness
	return null


func test_mashing_through_the_whole_sequence_still_completes_nothing() -> Variant:
	var result: Array = await _ready_scene_with_offering()
	var altar: NPC = result[2]
	if result[3] != "":
		return result[3]

	# Hold the key down: every press lands inside the minimum interval.
	DialogueManager.start(altar.sequence)
	var presses: int = 0
	while DialogueManager.is_active and presses < altar.sequence.lines.size() + 1:
		DialogueManager.advance()
		presses += 1
		if DialogueManager.current_line != null and DialogueManager.current_line.text == RUSH_INTERRUPT:
			break

	if GameState.is_realm_complete(&"jomolhari"):
		return "no amount of mashing may complete the realm"
	var line: DialogueLine = DialogueManager.current_line
	if line == null or line.text != RUSH_INTERRUPT:
		return "continuous mashing must end on the interrupt line, not complete"
	return null


func test_a_deliberate_offering_completes_and_jomo_answers() -> Variant:
	var result: Array = await _ready_scene_with_offering()
	var scene: Node = result[0]
	var altar: NPC = result[2]
	if result[3] != "":
		return result[3]

	await _offer_deliberately(altar)
	if DialogueManager.is_active:
		return "a deliberate offering should run to its natural end"

	if not GameState.is_realm_complete(&"jomolhari"):
		return "a deliberate offering must complete the realm"
	if GameState.awareness != 4:
		return "a first-try deliberate offering should grant 4 understanding, got %d" % GameState.awareness

	# Aum Jomo answers for the offering: "Better."
	var jomo: NPC = scene.get_node_or_null("AumJomo") as NPC
	if jomo == null or jomo.sequence == null:
		return "Aum Jomo should speak after the realm completes"
	if jomo.sequence.id != &"jhomo_quest_complete":
		return "Aum Jomo's line should be the quest-complete conversation, got '%s'" % jomo.sequence.id
	if jomo.sequence.lines[0].text != JOMO_ANSWER:
		return "Aum Jomo's answer should be '%s', got '%s'" % [
			JOMO_ANSWER, jomo.sequence.lines[0].text
		]

	# Let the bell and the light finish their moment before the scene is freed.
	await get_tree().create_timer(2.0).timeout
	return null


func test_picking_up_the_last_item_offers_the_offering_at_the_altar() -> Variant:
	var scene: Node = _new_scene()
	await get_tree().create_timer(0.1).timeout
	var quest: JomolhariQuest = scene.get_node_or_null("Quest") as JomolhariQuest
	GameState.mark_seen(quest.QUEST_STARTED)
	quest._refresh()

	# Pick each of the three things up the way a player would: the mark of
	# carrying it, then its conversation, with nothing else in between.
	for item in quest._items:
		var picked: DialogueSequence = item._pick_sequence()
		DialogueManager.start(picked)
		while DialogueManager.is_active:
			DialogueManager.advance()

	# The altar must move to the offering on its own after the last pickup,
	# with no other conversation to nudge it.
	var altar: NPC = scene.get_node_or_null("TsheringmaNey") as NPC
	if altar == null or altar.sequence == null:
		return "the altar must offer the offering after the third pickup, without a manual nudge"
	if altar.sequence.id != &"jhomo_altar_offering":
		return "the altar should offer the offering, got '%s'" % altar.sequence.id
	return null


func test_after_completion_jomos_answer_is_heard_once_then_the_lore() -> Variant:
	var result: Array = await _ready_scene_with_offering()
	var scene: Node = result[0]
	var altar: NPC = result[2]
	if result[3] != "":
		return result[3]
	var jomo: NPC = scene.get_node_or_null("AumJomo") as NPC
	if jomo == null:
		return "the scene must have Aum Jomo"

	# The student has met her before the offering: intro first, reminder after.
	var first_talk: DialogueSequence = jomo._pick_sequence()
	if first_talk.id != &"jhomo_quest_intro":
		return "a first meeting should play the quest intro, got '%s'" % first_talk.id
	var mid_talk: DialogueSequence = jomo._pick_sequence()
	if mid_talk.id != &"jhomo_quest_reminder":
		return "a mid-quest talk should be the reminder, got '%s'" % mid_talk.id

	# Complete the realm at a proper pace.
	await _offer_deliberately(altar)

	# Her answer for the offering is the full conversation, heard once...
	var answer: DialogueSequence = jomo._pick_sequence()
	if answer.id != &"jhomo_quest_complete":
		return "the first talk after completion should be Jomo's answer, got '%s'" % answer.id
	if answer.lines[0].text != JOMO_ANSWER:
		return "Jomo's answer should be '%s', got '%s'" % [JOMO_ANSWER, answer.lines[0].text]
	# ...and after that, the long conversation about the mountain returns.
	var later_talk: DialogueSequence = jomo._pick_sequence()
	if later_talk.id != &"jhomo_lhari":
		return "later talks should return to the lore conversation, got '%s'" % later_talk.id

	await get_tree().create_timer(2.0).timeout
	return null


func test_after_rushing_a_deliberate_retry_completes() -> Variant:
	var result: Array = await _ready_scene_with_offering()
	var altar: NPC = result[2]
	if result[3] != "":
		return result[3]

	# Rush once, and be corrected.
	DialogueManager.start(altar.sequence)
	DialogueManager.advance()
	var line: DialogueLine = DialogueManager.current_line
	if line == null or line.text != RUSH_INTERRUPT:
		return "the first attempt should have been interrupted"
	# Dismiss Aum Jomo's correction, the way a player would.
	DialogueManager.stop()

	# The altar still offers the ritual, so the student can try again.
	if altar.sequence == null or altar.sequence.id != &"jhomo_altar_offering":
		return "the altar must offer the offering again after a rush is interrupted"

	# This time, take the pace seriously.
	await _offer_deliberately(altar)
	if not GameState.is_realm_complete(&"jomolhari"):
		return "a deliberate retry after being corrected must complete the realm"
	if GameState.awareness != 3:
		return "a steady retry should grant 3 understanding (no first-try bonus), got %d" % GameState.awareness

	await get_tree().create_timer(2.0).timeout
	return null
