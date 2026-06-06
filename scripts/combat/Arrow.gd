extends Area2D

# Linear projectile. It only knows the damageable contract, not enemy types.

@export var speed: float = 400.0
@export var damage: int = 1
@export var max_lifetime: float = 2.0

var _direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _spent: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(target_position: Vector2) -> void:
	var delta_vec: Vector2 = target_position - global_position
	if delta_vec.length() > 0.01:
		_direction = delta_vec.normalized()
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	if _spent:
		return

	global_position += _direction * speed * delta
	_life += delta

	if _life >= max_lifetime:
		queue_free()

func _on_body_entered(other_body: Node) -> void:
	if _spent or other_body == null:
		return

	if not other_body.is_in_group("damageable"):
		return

	if other_body.has_method("apply_damage"):
		other_body.call("apply_damage", damage)

	_spent = true
	queue_free()
