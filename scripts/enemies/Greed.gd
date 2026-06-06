extends CharacterBody2D

signal hp_changed(current_hp: int, max_hp: int)
signal destroyed

@export var max_hp: int = 3
@export var move_speed: float = 55.0
@export var arrival_distance: float = 12.0
@export var attack_damage: int = 1
@export var attack_interval: float = 1.0
@export var coin_steal_amount: int = 1
@export var coin_steal_interval: float = 1.5
@export var coin_steal_distance: float = 40.0
@export var contact_damage_interval: float = 1.0
@export var contact_damage_distance: float = 40.0

@onready var body: Polygon2D = $Body

var hp: int = 3
var _target_position: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _attack_target: Node = null
var _attack_timer: float = 0.0
var _contact_effect_timer: float = 0.0

func _ready() -> void:
	add_to_group("greed")
	add_to_group("damageable")
	hp = max_hp
	_update_damage_visual()

func apply_damage(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return

	hp = max(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	_update_damage_visual()

	if hp == 0:
		destroyed.emit()
		queue_free()

func get_hp() -> int:
	return hp

func _update_damage_visual() -> void:
	if body == null:
		return

	var hp_ratio: float = 1.0
	if max_hp > 0:
		hp_ratio = clamp(float(hp) / float(max_hp), 0.0, 1.0)

	var damage_t: float = 1.0 - hp_ratio
	body.color = Color(
		lerp(0.18, 0.85, damage_t),
		lerp(0.16, 0.12, damage_t),
		lerp(0.28, 0.12, damage_t),
		1.0
	)

func set_target_position(target_position: Vector2) -> void:
	_target_position = target_position
	_has_target = true

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	_refresh_player_target()

	if _has_attack_target():
		_attack_wall(delta)
	elif _has_target:
		_move_toward_target(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)

	move_and_slide()
	_detect_wall_collision()
	_process_contact_effects(delta)

func _refresh_player_target() -> void:
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player is Node2D:
			_target_position = (player as Node2D).global_position
			_has_target = true
			return

func _move_toward_target(delta: float) -> void:
	var x_distance: float = _target_position.x - global_position.x

	if absf(x_distance) <= arrival_distance:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		return

	velocity.x = signf(x_distance) * move_speed

func _detect_wall_collision() -> void:
	if _has_attack_target():
		return

	for index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(index)
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("wall"):
			_attack_target = collider as Node
			_attack_timer = 0.0
			return

func _has_attack_target() -> bool:
	return _attack_target != null and is_instance_valid(_attack_target) and _attack_target.has_method("apply_damage")

func _attack_wall(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
	_attack_timer -= delta

	if _attack_timer > 0.0:
		return

	_attack_target.call("apply_damage", attack_damage)
	_attack_timer = max(attack_interval, 0.1)

	if not is_instance_valid(_attack_target):
		_attack_target = null

func _process_contact_effects(delta: float) -> void:
	var contact_target: Node2D = _find_nearest_contact_target()
	if contact_target == null:
		_contact_effect_timer = 0.0
		return

	_contact_effect_timer -= delta
	if _contact_effect_timer > 0.0:
		return

	if contact_target.is_in_group("player"):
		ResourceManager.spend_coins(coin_steal_amount)
		_contact_effect_timer = max(coin_steal_interval, 0.1)
	elif _can_damage_contact_target(contact_target):
		contact_target.call("apply_damage", attack_damage)
		_contact_effect_timer = max(contact_damage_interval, 0.1)

func _find_nearest_contact_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for player_node in get_tree().get_nodes_in_group("player"):
		if not player_node is Node2D:
			continue
		var player: Node2D = player_node as Node2D
		var player_distance: float = global_position.distance_to(player.global_position)
		if player_distance <= coin_steal_distance and player_distance < nearest_distance:
			nearest = player
			nearest_distance = player_distance

	for villager_node in get_tree().get_nodes_in_group("villager"):
		if not villager_node is Node2D:
			continue
		var villager: Node2D = villager_node as Node2D
		var villager_distance: float = global_position.distance_to(villager.global_position)
		if villager_distance <= contact_damage_distance and villager_distance < nearest_distance:
			nearest = villager
			nearest_distance = villager_distance

	return nearest

func _can_damage_contact_target(target: Node) -> bool:
	return target.is_in_group("damageable") and target.has_method("apply_damage")
