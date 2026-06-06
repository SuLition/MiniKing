extends CharacterBody2D

const WALK_SPEED: float = 120.0
const RUN_SPEED: float = 220.0
const JUMP_VELOCITY: float = -300.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group(GameGroups.PLAYER)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction: float = Input.get_axis("move_left", "move_right")
	var current_speed: float = WALK_SPEED

	if Input.is_action_pressed("run"):
		current_speed = RUN_SPEED

	if direction != 0.0:
		velocity.x = direction * current_speed
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 8.0 * delta)

	move_and_slide()
	update_animation(direction)

func update_animation(direction: float) -> void:
	if not is_on_floor():
		animated_sprite.play("Jump")
		return

	if direction == 0:
		animated_sprite.play("Idle")
		return

	if Input.is_action_pressed("run"):
		animated_sprite.play("Run")
	else:
		animated_sprite.play("Walk")
