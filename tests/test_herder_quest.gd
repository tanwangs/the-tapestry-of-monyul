extends Node
## "The Herder's Path": the second Jomolhari side quest. Dema asks, the trail
## of signs speaks one at a time in walking order, the yak is found and brought
## home, and the woven cord changes hands.
##
## Each test states one behaviour the rest of the game relies on.

const SCENE: String = "res://scenes/nyes/jhomo_lhari.tscn"

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


func _new_scene() -> Array:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(scene)
	_spawned.append(scene)
	await get_tree().create_timer(0.1).timeout
	var quest: HerderQuest = scene.get_node_or_null("HerderQuest") as HerderQuest
	var herder: NPC = scene.get_node_or_null("Dema") as NPC
	var yak: NPC = scene.get_node_or_null("Yak") as NPC
	return [scene, quest, herder, yak]


## Plays a conversation to its natural end, the way a player reads it through.
func _play(sequence: DialogueSequence) -> void:
	DialogueManager.start(sequence)
	while DialogueManager.is_active:
		DialogueManager.advance()


func test_the_quest_is_wired_into_the_scene() -> Variant:
	var result: Array = await _new_scene()
	var quest: HerderQuest = result[1]
	if quest == null:
		return "the Jhomo Lhari scene must have a HerderQuest node"
	if quest._clues.size() != 4:
		return "the herder's trail must have exactly four clue markers, got %d" % quest._clues.size()
	var keys: Dictionary = {}
	for clue in quest._clues:
		if clue == null or clue.lore_key == &"":
			return "every clue marker needs its own lore key"
		if keys.has(clue.lore_key):
			return "every clue marker needs a different lore key"
		keys[clue.lore_key] = true
	if result[2] == null:
		return "the scene must have Dema the herder"
	if result[3] == null:
		return "the scene must have the lost yak"
	return null


## The new yak herder sheet: 6x10 grid of 48x48 frames, offset 32px down from
## the sheet's top. Dema stands at her spot and talks - she never walks in the
## game - so her art is the sheet's front idle row (row 0, y 32), all six
## breathing frames, cut 48x48 from the new sheet so she can never quietly
## fall back to the old static placeholder.
func test_the_herders_art_is_sliced_from_her_sheet() -> Variant:
	var result: Array = await _new_scene()
	var herder: NPC = result[2]
	if herder == null:
		return "the scene must have Dema the herder"
	var animated: AnimatedSprite2D = herder.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated == null or animated.sprite_frames == null:
		return "Dema must carry her artwork as an animated character"

	var frames: SpriteFrames = animated.sprite_frames
	if not frames.has_animation(&"idle_front"):
		return "the herder sheet must be sliced into an idle_front animation"
	var count: int = frames.get_frame_count(&"idle_front")
	if count != 6:
		return "the idle should hold the sheet's whole 6-frame row, got %d" % count
	for index: int in count:
		var frame: AtlasTexture = frames.get_frame_texture(&"idle_front", index) as AtlasTexture
		if frame == null or frame.atlas == null \
				or frame.atlas.resource_path != "res://assets/sprites/yak_herder.png":
			return "idle_front frame %d is not cut from the yak herder sheet" % index
		if frame.region.position.y != 32.0 or frame.region.size != Vector2(48, 48):
			return "idle_front frame %d is not a 48x48 cut of its own row" % index
	return null


func test_the_trail_is_silent_until_dema_is_asked() -> Variant:
	var result: Array = await _new_scene()
	var quest: HerderQuest = result[1]
	var herder: NPC = result[2]
	var yak: NPC = result[3]
	if quest == null or herder == null or yak == null:
		return "the scene must have the herder quest, Dema and the yak"

	# Dema herself is talkable before anything else happens...
	if herder.sequence == null or herder.sequence.id != &"herder_intro":
		return "Dema's first talk should ask the student to follow the trail"
	# ...but the trail says nothing yet.
	for clue in quest._clues:
		if clue.sequence != null:
			return "no clue may speak before Dema has asked"
	if yak.sequence != null:
		return "the yak must not be findable before Dema has asked"
	return null


func test_the_trail_speaks_one_sign_at_a_time_in_walking_order() -> Variant:
	var result: Array = await _new_scene()
	var quest: HerderQuest = result[1]
	var herder: NPC = result[2]
	if quest == null or herder == null:
		return "the scene must have the herder quest and Dema"

	# Ask, the way a player does: hear Dema out.
	_play(herder.sequence)
	if not GameState.has_seen(quest.QUEST_STARTED):
		return "hearing Dema's intro must start the trail"

	# Only the first sign speaks.
	if quest._clues[0].sequence == null or quest._clues[0].sequence.id != &"herder_clue_1":
		return "the first sign must speak once Dema has asked"
	for i: int in range(1, quest._clues.size()):
		if quest._clues[i].sequence != null:
			return "sign %d must stay silent until the signs before it are read" % (i + 1)

	# Read the first sign where it stands: the second begins to speak, and only it.
	_play(quest._clues[0].sequence)
	if quest._clues[1].sequence == null or quest._clues[1].sequence.id != &"herder_clue_2":
		return "the second sign must speak after the first is read"
	if quest._clues[2].sequence != null or quest._clues[3].sequence != null:
		return "skipping a sign must not unlock the ones after it - the player has to backtrack"
	if quest._clues[0].sequence != null:
		return "a read sign must fall silent"
	return null


func test_the_yak_is_found_only_after_the_whole_trail_is_read() -> Variant:
	var result: Array = await _new_scene()
	var quest: HerderQuest = result[1]
	var yak: NPC = result[3]
	if quest == null or yak == null:
		return "the scene must have the herder quest and the yak"

	GameState.mark_seen(quest.QUEST_STARTED)
	quest._refresh()
	for i: int in range(3):
		if quest._clues[i].sequence == null:
			return "clue %d should be readable in order" % (i + 1)
		_play(quest._clues[i].sequence)

	# Three of four signs read: the yak is still just a yak.
	if yak.sequence != null:
		return "the yak must not be findable while a sign is still unread"

	_play(quest._clues[3].sequence)
	if yak.sequence == null or yak.sequence.id != &"herder_yak_found":
		return "the yak must speak once the whole trail has been read"
	return null


func test_bringing_the_yak_home_completes_the_quest() -> Variant:
	var result: Array = await _new_scene()
	var quest: HerderQuest = result[1]
	var herder: NPC = result[2]
	var yak: NPC = result[3]
	if quest == null or herder == null or yak == null:
		return "the scene must have the herder quest, Dema and the yak"

	GameState.mark_seen(quest.QUEST_STARTED)
	quest._refresh()
	for clue in quest._clues:
		_play(clue.sequence)

	# Find the yak: he follows the student back down, so he leaves his hollow.
	_play(yak.sequence)
	if not GameState.has_seen(quest.YAK_FOUND):
		return "finding the yak must be remembered"
	if yak.visible:
		return "the found yak should walk back down with the student, not stay on the ridge"
	if herder.sequence == null or herder.sequence.id != &"herder_thanks":
		return "Dema should be waiting to thank the student for the yak"

	# The thanks is the resolution: the cord, the understanding, the quest closed.
	_play(herder.sequence)
	if not GameState.jomolhari_side2_complete:
		return "Dema's thanks must complete the second Jomolhari side quest"
	if not GameState.has_woven_cord:
		return "Dema must give the woven cord when she gives her thanks"
	if GameState.awareness != quest.SIDE_AWARENESS:
		return "bringing the yak home should grant %d understanding, got %d" % [quest.SIDE_AWARENESS, GameState.awareness]
	if not yak.visible:
		return "the yak should be standing by Dema's stone once the quest is closed"
	if herder.sequence == null or herder.sequence.id != &"herder_done":
		return "Dema should settle into her after-quest conversation"
	if herder.global_position.distance_to(yak.global_position) > 80.0:
		return "the yak should be standing near Dema at the trailhead"
	return null


func test_a_half_read_trail_survives_leaving_and_coming_back() -> Variant:
	var result: Array = await _new_scene()
	var quest: HerderQuest = result[1]
	if quest == null:
		return "the scene must have a HerderQuest node"
	GameState.mark_seen(quest.QUEST_STARTED)
	quest._refresh()
	_play(quest._clues[0].sequence)
	_play(quest._clues[1].sequence)
	var first_yak: NPC = quest._yak
	if first_yak.sequence != null:
		return "the yak must stay hidden while signs are still unread"

	# Leave the map and come back: the trail picks up where it was left.
	var second: Array = await _new_scene()
	var quest2: HerderQuest = second[1]
	if quest2 == null:
		return "the reloaded scene must have a HerderQuest node"
	if quest2.clues_read() != 2:
		return "two signs read should survive the reload, got %d" % quest2.clues_read()
	if quest2._clues[0].sequence != null or quest2._clues[1].sequence != null:
		return "already-read signs must stay silent after a reload"
	if quest2._clues[2].sequence == null:
		return "the third sign must speak after a reload with two signs read"
	return null


func test_the_first_side_quest_is_untouched_by_this_one() -> Variant:
	var result: Array = await _new_scene()
	var quest: HerderQuest = result[1]
	var herder: NPC = result[2]
	if quest == null or herder == null:
		return "the scene must have the herder quest and Dema"

	# Play the herder's path from end to end.
	GameState.mark_seen(quest.QUEST_STARTED)
	quest._refresh()
	for clue in quest._clues:
		_play(clue.sequence)
	_play(quest._yak.sequence)
	_play(herder.sequence)

	if GameState.is_side_complete(&"jomolhari"):
		return "the listening quest's own completion flag must not be set by the herder's path"
	if GameState.is_realm_complete(&"jomolhari"):
		return "the herder's path must not complete the realm"
	return null
