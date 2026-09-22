extends CharacterBody2D
## The student on the nature retreat.
##
## Walks with WASD or the arrow keys, and presses the talk key (E, Space or
## Enter) to speak with whoever is standing nearby. Movement locks while a
## conversation is on screen so the student cannot wander off mid-sentence.

const SPEED: float = 100.0
## How close a character must be before the student can talk to them.
const TALK_RANGE: float = 60.0

var _facing: String = "down"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	_sprite.play("idle_front")


func _physics_process(_delta: float) -> void:
	if DialogueManager.is_active or Global.ui_locked:
		velocity = Vector2.ZERO
		_animate(false)
		move_and_slide()
		return

	# Arrow keys and WASD both drive the student; either set works on its own.
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction == Vector2.ZERO:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		_animate(false)
	else:
		velocity = direction * SPEED
		if direction.x != 0.0:
			_facing = "right" if direction.x > 0.0 else "left"
		else:
			_facing = "down" if direction.y > 0.0 else "up"
		_animate(true)

	move_and_slide()


func _animate(moving: bool) -> void:
	var suffix: String = "front"
	match _facing:
		"up":
			suffix = "back"
		"left", "right":
			suffix = "side"

	_sprite.flip_h = _facing == "left"
	_sprite.play(("walk_" if moving else "idle_") + suffix)


func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active or Global.ui_locked:
		return
	if not event.is_action_pressed("interact"):
		return

	# First, try interacting with a water area.
	var water: DrakayWaterInteract = _nearest_water()
	if water != null:
		get_viewport().set_input_as_handled()
		water.interact()
		return

	# Then a taxi whose door the student is standing at: the taxi waits well
	# clear of the post it was called from, so it is found by its own position.
	var rank: TaxiRank = _nearest_boardable_rank()
	if rank != null:
		get_viewport().set_input_as_handled()
		rank.interact()
		return

	var target: NPC = _nearest_talkable()
	if target == null:
		return

	get_viewport().set_input_as_handled()
	target.interact()


## The closest character that is willing to talk right now, or null.
func _nearest_talkable() -> NPC:
	var best: NPC = null
	var best_distance: float = TALK_RANGE

	for node in get_tree().get_nodes_in_group("npc"):
		var npc: NPC = node as NPC
		if npc == null or not npc.has_talk():
			continue
		var distance: float = global_position.distance_to(npc.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = npc

	return best


## The closest water interactable, or null if none is nearby.
func _nearest_water() -> DrakayWaterInteract:
	var best: DrakayWaterInteract = null
	var best_distance: float = TALK_RANGE

	for node in get_tree().get_nodes_in_group("drakay_water"):
		var water: DrakayWaterInteract = node as DrakayWaterInteract
		if water == null:
			continue
		var distance: float = global_position.distance_to(water.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = water

	return best


## The closest taxi that is waiting and whose door the student stands at, or
## null. Distance is measured to the taxi itself, which parks away from the
## post the ride was called from.
func _nearest_boardable_rank() -> TaxiRank:
	var best: TaxiRank = null
	var best_distance: float = TALK_RANGE

	for node in get_tree().get_nodes_in_group("taxi_rank"):
		var rank: TaxiRank = node as TaxiRank
		if rank == null or not rank.can_board():
			continue
		var distance: float = global_position.distance_to(rank.board_point())
		if distance <= best_distance:
			best_distance = distance
			best = rank

	return best
