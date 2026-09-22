class_name QuestLog
extends RefCounted
## The trackable quest registry: one row for every quest the retreat can ask
## of the student, each reading its own progress straight out of GameState.
##
## This is pure data plus pure questions - nothing here draws anything or
## reacts to anything. The journal menu reads it to lay out the quest list,
## and any future HUD or save screen can read it the same way.
##
## A quest's `status` is one of three states:
##   PENDING   - the ask has not been made yet; the student does not know it.
##   ACTIVE    - the ask has been made and the work is still open.
##   COMPLETED - GameState says the quest is finished.

## The three states a trackable quest can be in.
enum Status { PENDING, ACTIVE, COMPLETED }

## Which GameState completion flag a quest answers to.
const KIND_MAIN: StringName = &"main"
const KIND_SIDE: StringName = &"side"
const KIND_SIDE2: StringName = &"side2"

## Every trackable quest, in trek order. `started_key` is the GameState lore
## key that is marked the first time the ask is made; `kind` + `realm` pick
## the completion flag.
const QUESTS: Array[Dictionary] = [
	{
		"id": &"drakay_pangtsho_main",
		"realm": &"drakay_pangtsho",
		"kind": KIND_MAIN,
		"title": "The Disturbed Lake",
		"place": "Drakay Pangtsho",
		"started_key": &"drakay_pangtsho_quest_started",
		"description": "Notice what is wrong with the lake, gather what was scattered, and restore the offering stones.",
	},
	{
		"id": &"drakay_pangtsho_side",
		"realm": &"drakay_pangtsho",
		"kind": KIND_SIDE,
		"title": "Reflections on the Water",
		"place": "Drakay Pangtsho",
		"started_key": &"drakay_pangtsho_quest_started",
		"description": "Sit for a while at the three quiet viewpoints around the lake.",
	},
	{
		"id": &"drakay_pangtsho_side2",
		"realm": &"drakay_pangtsho",
		"kind": KIND_SIDE2,
		"title": "Mending What's Shared",
		"place": "Drakay Pangtsho",
		"started_key": &"mending_quest_started",
		"description": "Gather reeds from the shoreline with Choden and mend her torn platform, knot by unhurried knot.",
	},
	{
		"id": &"taktsang_main",
		"realm": &"taktsang",
		"kind": KIND_MAIN,
		"title": "The Keepers of Memory",
		"place": "Taktsang",
		"started_key": &"taktsang_quest_started",
		"description": "Hear the three keepers' fragments of the story, retell the one that stayed with you, and ring the evening bell.",
	},
	{
		"id": &"taktsang_side",
		"realm": &"taktsang",
		"kind": KIND_SIDE,
		"title": "Prayer Wheels of Intention",
		"place": "Taktsang",
		"started_key": &"taktsang_quest_started",
		"description": "Set each of the prayer wheels along the trail turning.",
	},
	{
		"id": &"taktsang_side2",
		"realm": &"taktsang",
		"kind": KIND_SIDE2,
		"title": "The Pilgrim's Climb",
		"place": "Taktsang",
		"started_key": &"pilgrim_quest_started",
		"description": "Walk the last stretch of trail with the old pilgrim, at her own pace.",
	},
	{
		"id": &"jomolhari_main",
		"realm": &"jomolhari",
		"kind": KIND_MAIN,
		"title": "The Mountain's Offering",
		"place": "Jhomolhari",
		"started_key": &"jomolhari_quest_started",
		"description": "Gather the incense, the butter lamp and the offering bowl, and steady the altar at Tsheringma Ney.",
	},
	{
		"id": &"jomolhari_side",
		"realm": &"jomolhari",
		"kind": KIND_SIDE,
		"title": "The Listening Places",
		"place": "Jhomolhari",
		"started_key": &"jomolhari_quest_started",
		"description": "Sit for a while at the three quiet places the mountain keeps.",
	},
	{
		"id": &"jomolhari_side2",
		"realm": &"jomolhari",
		"kind": KIND_SIDE2,
		"title": "The Herder's Path",
		"place": "Jhomolhari",
		"started_key": &"herder_quest_started",
		"description": "Follow the trail of signs Dema's lost yak left across the mountainside, and bring him home.",
	},
]


## The completion state of one quest, read out of GameState.
static func status_of(quest: Dictionary) -> int:
	if is_quest_complete(quest):
		return Status.COMPLETED
	if GameState.has_seen(quest["started_key"]):
		return Status.ACTIVE
	return Status.PENDING


## True when GameState says this quest's flag is set.
static func is_quest_complete(quest: Dictionary) -> bool:
	var realm: StringName = quest["realm"]
	match quest["kind"]:
		KIND_MAIN:
			return GameState.is_realm_complete(realm)
		KIND_SIDE:
			return GameState.is_side_complete(realm)
		KIND_SIDE2:
			match realm:
				&"jomolhari":
					return GameState.jomolhari_side2_complete
				&"drakay_pangtsho":
					return GameState.drakay_pangtsho_side2_complete
				&"taktsang":
					return GameState.taktsang_side2_complete
	return false


## Every quest still waiting to be asked for or finished: the pending and the
## active, in one list, in trek order.
static func open_quests() -> Array[Dictionary]:
	var open: Array[Dictionary] = []
	for quest in QUESTS:
		var status: int = status_of(quest)
		if status == Status.PENDING or status == Status.ACTIVE:
			open.append(quest)
	return open


## Every quest GameState says is finished, in trek order.
static func completed_quests() -> Array[Dictionary]:
	var done: Array[Dictionary] = []
	for quest in QUESTS:
		if status_of(quest) == Status.COMPLETED:
			done.append(quest)
	return done
