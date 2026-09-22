extends Node
## The opening of the retreat: the dream that starts it, the two tutorial
## lessons that follow, and the wiring that puts them in the village.

const GAME_SCENE: String = "res://scenes/game.tscn"
const QUEST_HUD_SCENE: String = "res://scenes/ui/quest_hud.tscn"
const NPC_SCENE: String = "res://scenes/npc.tscn"


func before_each() -> void:
	DialogueManager.stop()
	GameState.reset()
	Global.ui_locked = false


## Anything a test puts in the tree is freed for real when that test ends. A
## prompt left behind would otherwise still be listening to conversations, and
## would answer for the next test as well as this one.
var _spawned: Array[Node] = []


func after_each() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


## Runs a conversation through to its last line.
func _play_out(path: String) -> void:
	var sequence: DialogueSequence = load(path) as DialogueSequence
	if sequence == null:
		return
	DialogueManager.start(sequence)
	var guard: int = 0
	while DialogueManager.is_active and guard < 32:
		DialogueManager.advance()
		guard += 1


func _new_hud() -> VillageQuests:
	var hud: VillageQuests = (load(QUEST_HUD_SCENE) as PackedScene).instantiate() as VillageQuests
	add_child(hud)
	_spawned.append(hud)
	return hud


func test_the_village_scene_wires_the_opening_and_the_lessons() -> Variant:
	var packed: PackedScene = load(GAME_SCENE)
	if packed == null:
		return "%s failed to load" % GAME_SCENE
	var game: Node = packed.instantiate()

	var opening: Node = game.get_node_or_null("Opening")
	if opening == null:
		game.free()
		return "the village scene has no Opening node, so nothing plays the dream"
	if opening.get_node_or_null("Mood") == null:
		game.free()
		return "the Opening has no Mood light to go cold before the dream"
	if opening.get_node_or_null("DreamOverlay") == null:
		game.free()
		return "the Opening has no DreamOverlay"
	if opening.get_node_or_null("QuestHud") == null:
		game.free()
		return "the Opening has no QuestHud, so no lesson prompt would appear"

	var flags: Node = game.get_node_or_null("PrayerFlags")
	var bowl: Node = game.get_node_or_null("WaterBowl")
	if flags == null or bowl == null:
		game.free()
		return "the village needs both a prayer flags and a water bowl object"
	if flags.get("sequence") == null or bowl.get("sequence") == null:
		game.free()
		return "both lesson objects need a conversation"
	if String(flags.get("lore_key")) == "" or String(bowl.get("lore_key")) == "":
		game.free()
		return "both lesson objects need a lore key so a repeat visit can be shorter"
	if flags.get("lore_key") == bowl.get("lore_key"):
		game.free()
		return "the two lesson objects must not share a lore key"

	var flags_id: String = String((flags.get("sequence") as DialogueSequence).id)
	var bowl_id: String = String((bowl.get("sequence") as DialogueSequence).id)
	if flags_id != "quest_prayer_flags":
		game.free()
		return "the prayer flags should teach the flags lesson, got '%s'" % flags_id
	if bowl_id != "quest_water_bowl":
		game.free()
		return "the water bowl should teach the water lesson, got '%s'" % bowl_id

	# The lesson says the bowl comes after walking east, so it must be east.
	var flags_pos: Vector2 = (flags as Node2D).position
	var bowl_pos: Vector2 = (bowl as Node2D).position
	if bowl_pos.x <= flags_pos.x:
		game.free()
		return "the water bowl should sit east of the prayer flags"
	for prop in [flags, bowl]:
		var pos: Vector2 = (prop as Node2D).position
		if pos.x < 0.0 or pos.x > 1056.0 or pos.y < 0.0 or pos.y > 273.0:
			game.free()
			return "%s sits outside the village map at %s" % [prop.name, str(pos)]

	game.free()
	return null


func test_the_dream_runs_before_the_first_lesson() -> Variant:
	var game: Node = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var overlay: DreamOverlay = game.get_node_or_null("Opening/DreamOverlay") as DreamOverlay
	var quests: VillageQuests = game.get_node_or_null("Opening/QuestHud") as VillageQuests
	if overlay == null or quests == null:
		game.queue_free()
		return "the Opening is missing its dream or its lesson hud"
	if not overlay.visible:
		game.queue_free()
		return "the dream should be on screen when the retreat opens"
	if quests._started:
		game.queue_free()
		return "the lessons must wait until the dream is over"
	if not Global.ui_locked:
		game.queue_free()
		return "the student should be held still while the dream plays"

	game.queue_free()
	Global.ui_locked = false
	await get_tree().process_frame
	return null


func test_a_returning_student_skips_the_dream() -> Variant:
	GameState.mark_seen(&"opening_seen")
	var game: Node = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var overlay: DreamOverlay = game.get_node_or_null("Opening/DreamOverlay") as DreamOverlay
	var mood: CanvasModulate = game.get_node_or_null("Opening/Mood") as CanvasModulate
	if overlay == null or mood == null:
		game.queue_free()
		return "the Opening is missing its dream or its mood light"
	if overlay.visible:
		game.queue_free()
		return "a student who has already seen the opening should not dream again"
	if mood.color != VillageOpening.NORMAL_MOOD:
		game.queue_free()
		return "the village should be lit normally on a return visit"

	game.queue_free()
	Global.ui_locked = false
	await get_tree().process_frame
	return null


func test_the_lessons_announce_the_first_step_once() -> Variant:
	var hud: VillageQuests = _new_hud()
	hud.begin()
	if not hud._started:
		hud.queue_free()
		return "begin() should start the lessons"
	var prompt: String = (hud.get_node("Objective") as Label).text
	if prompt != VillageQuests.PROMPTS[VillageQuests.Step.MOVE]:
		hud.queue_free()
		return "the first lesson should ask the student to move, got '%s'" % prompt
	hud.begin()
	if (hud.get_node("Objective") as Label).text != prompt:
		hud.queue_free()
		return "begin() must not restart a lesson that has already been announced"
	hud.queue_free()
	return null


func test_the_lessons_are_not_repeated_for_a_returning_student() -> Variant:
	GameState.mark_seen(&"village_tutorials")
	var hud: VillageQuests = _new_hud()
	hud.begin()
	var started: bool = hud._started
	hud.queue_free()
	if started:
		return "a student who already finished the lessons should not be taught them again"
	return null


func test_walking_and_reading_both_objects_finishes_the_lessons() -> Variant:
	var hud: VillageQuests = _new_hud()
	hud.begin()

	# Lesson one: walking. A stand-in for the student is enough - the lesson
	# only measures how far the player has travelled.
	var walker := Node2D.new()
	walker.add_to_group("player")
	add_child(walker)
	walker.global_position = Vector2(200, 140)
	hud._process(0.016)
	walker.global_position = Vector2(200, 140 + VillageQuests.MOVE_THRESHOLD + 1.0)
	hud._process(0.016)
	if hud.current_step() != VillageQuests.Step.FLAGS:
		hud.queue_free()
		return "walking far enough should move the lessons on to the flags"
	if GameState.awareness != 1:
		hud.queue_free()
		return "the walking lesson should raise awareness to 1, got %d" % GameState.awareness

	# Lesson two: reading the two objects, in the order the prompts ask for.
	_play_out("res://dialogue/quest_prayer_flags.tres")
	if hud.current_step() != VillageQuests.Step.WATER:
		hud.queue_free()
		return "reading the prayer flags should move the lessons on to the water bowl"
	if GameState.awareness != 2:
		hud.queue_free()
		return "the flags lesson should raise awareness to 2, got %d" % GameState.awareness
	_play_out("res://dialogue/quest_water_bowl.tres")
	if hud.current_step() != VillageQuests.Step.DONE:
		hud.queue_free()
		return "reading the water bowl should finish the lessons"

	if not GameState.has_seen(&"village_tutorials"):
		hud.queue_free()
		return "finishing the lessons should be remembered"
	if GameState.awareness != 2:
		hud.queue_free()
		return "finishing the last lesson should not raise awareness again, got %d" % GameState.awareness
	hud.queue_free()
	return null


func test_the_wrong_conversation_does_not_finish_a_lesson() -> Variant:
	var hud: VillageQuests = _new_hud()
	hud.begin()
	hud._step = VillageQuests.Step.FLAGS
	_play_out("res://dialogue/village_unease.tres")
	var step: int = hud.current_step()
	hud.queue_free()
	if step != VillageQuests.Step.FLAGS:
		return "only the lesson's own conversation should move it on"
	return null


func test_an_npc_gives_the_full_talk_then_the_short_one() -> Variant:
	var npc: NPC = (load(NPC_SCENE) as PackedScene).instantiate() as NPC
	npc.sequence = DialogueSequence.from_script(&"test_full", [["Aum Jomo", "the long story"]])
	npc.repeat_sequence = DialogueSequence.from_script(&"test_short", [["Aum Jomo", "as I said"]])
	npc.lore_key = &"test_npc"
	add_child(npc)
	_spawned.append(npc)

	if npc.has_talk():
		npc.queue_free()
		return "an NPC out of range should not be talkable"
	npc._player_nearby = true
	if not npc.has_talk():
		npc.queue_free()
		return "an NPC in range with a conversation should be talkable"
	if not npc.interact():
		npc.queue_free()
		return "interact() should start the first conversation"
	if DialogueManager.current_line == null or DialogueManager.current_line.text != "the long story":
		npc.queue_free()
		return "the first talk should be the full version"
	_play_out("res://dialogue/guide_repeat.tres")
	DialogueManager.stop()

	if not npc.interact():
		npc.queue_free()
		return "the NPC should be talkable again afterwards"
	if DialogueManager.current_line == null or DialogueManager.current_line.text != "as I said":
		npc.queue_free()
		return "the second talk should be the short version"
	DialogueManager.stop()
	npc.queue_free()
	return null
