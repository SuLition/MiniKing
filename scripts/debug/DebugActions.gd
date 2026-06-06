class_name DebugActions
extends Node

@export var infinite_coin_floor: int = 99
@export var add_coin_amount: int = 10
@export var large_add_coin_amount: int = 50

@export var time_manager_path: NodePath
@export var villager_parent_path: NodePath
@export var enemy_parent_path: NodePath
@export var villager_spawn_path: NodePath
@export var left_enemy_spawn_path: NodePath
@export var right_enemy_spawn_path: NodePath
@export var enemy_target_path: NodePath

@export var villager_scene: PackedScene
@export var greed_scene: PackedScene
@export var spawnable_professions: Array[ProfessionDefinition] = []

var _infinite_coins_enabled: bool = false
var _time_paused: bool = false

func _ready() -> void:
	ResourceManager.coins_changed.connect(_on_coins_changed)

func set_infinite_coins_enabled(enabled: bool) -> void:
	_infinite_coins_enabled = enabled
	_enforce_infinite_coins()

func is_infinite_coins_enabled() -> bool:
	return _infinite_coins_enabled

func add_coins() -> void:
	ResourceManager.add_coins(add_coin_amount)

func add_many_coins() -> void:
	ResourceManager.add_coins(large_add_coin_amount)

func reset_coins() -> void:
	ResourceManager.reset_coins()

func spawn_villager() -> void:
	_spawn_villager(null)

func spawn_profession(profession: ProfessionDefinition) -> void:
	_spawn_villager(profession)

func get_spawnable_professions() -> Array[ProfessionDefinition]:
	return spawnable_professions

func spawn_greed_left() -> void:
	_spawn_greed(_get_marker_position(left_enemy_spawn_path))

func spawn_greed_right() -> void:
	_spawn_greed(_get_marker_position(right_enemy_spawn_path))

func clear_enemies() -> void:
	_clear_group(GameGroups.GREED)

func clear_villagers() -> void:
	_clear_group(GameGroups.VILLAGER)

func clear_tasks() -> void:
	TaskBoard.clear()

func toggle_time_pause() -> void:
	var time_manager: Node = get_node_or_null(time_manager_path)
	if time_manager == null:
		push_warning("DebugActions has no valid TimeManager path.")
		return

	if _time_paused:
		if time_manager.has_method("resume_cycle"):
			time_manager.call("resume_cycle")
	else:
		if time_manager.has_method("pause_cycle"):
			time_manager.call("pause_cycle")
	_time_paused = not _time_paused

func restart_time_cycle() -> void:
	var time_manager: Node = get_node_or_null(time_manager_path)
	if time_manager != null and time_manager.has_method("start_cycle"):
		time_manager.call("start_cycle")
		_time_paused = false

func get_status() -> Dictionary:
	return {
		"coins": ResourceManager.get_coins(),
		"villagers": get_tree().get_nodes_in_group(GameGroups.VILLAGER).size(),
		"enemies": get_tree().get_nodes_in_group(GameGroups.GREED).size(),
		"tasks": TaskBoard.open_task_count(),
		"infinite_coins": _infinite_coins_enabled,
		"time_paused": _time_paused,
	}

func _on_coins_changed(_before_amount: int, _after_amount: int, _delta_amount: int) -> void:
	_enforce_infinite_coins()

func _enforce_infinite_coins() -> void:
	if not _infinite_coins_enabled:
		return

	var current_coins: int = ResourceManager.get_coins()
	if current_coins < infinite_coin_floor:
		ResourceManager.add_coins(infinite_coin_floor - current_coins)

func _spawn_villager(profession: ProfessionDefinition) -> void:
	if villager_scene == null:
		push_warning("DebugActions has no villager_scene assigned.")
		return

	var villager_node: Node = villager_scene.instantiate()
	if not villager_node is Node2D:
		villager_node.queue_free()
		push_warning("DebugActions villager_scene must instantiate a Node2D.")
		return

	var villager: Node2D = villager_node as Node2D
	var spawn_position: Vector2 = _get_marker_position(villager_spawn_path)
	var parent: Node = _get_villager_parent()

	parent.add_child(villager)
	villager.global_position = spawn_position + _spawn_offset(parent)

	if villager.has_method("set_home_position"):
		villager.call("set_home_position", spawn_position)
	if profession != null and villager.has_method("assign_profession"):
		villager.call("assign_profession", profession)

func _spawn_greed(spawn_position: Vector2) -> void:
	if greed_scene == null:
		push_warning("DebugActions has no greed_scene assigned.")
		return

	var greed_node: Node = greed_scene.instantiate()
	if not greed_node is Node2D:
		greed_node.queue_free()
		push_warning("DebugActions greed_scene must instantiate a Node2D.")
		return

	var greed: Node2D = greed_node as Node2D
	_get_enemy_parent().add_child(greed)
	greed.global_position = spawn_position

	if greed.has_method("set_target_position"):
		greed.call("set_target_position", _get_marker_position(enemy_target_path))

func _clear_group(group_name: StringName) -> void:
	for node: Node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			node.queue_free()

func _get_villager_parent() -> Node:
	var parent: Node = get_node_or_null(villager_parent_path)
	if parent != null:
		return parent
	return get_parent()

func _get_enemy_parent() -> Node:
	var parent: Node = get_node_or_null(enemy_parent_path)
	if parent != null:
		return parent
	return get_parent()

func _get_marker_position(marker_path: NodePath) -> Vector2:
	var marker: Node2D = get_node_or_null(marker_path) as Node2D
	if marker != null:
		return marker.global_position
	return Vector2.ZERO

func _spawn_offset(parent: Node) -> Vector2:
	var index: int = parent.get_child_count() % 6
	return Vector2(float(index) * 18.0, 0.0)
