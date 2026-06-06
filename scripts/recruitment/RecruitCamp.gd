extends Area2D

signal recruited(villager: Node2D)

@export var recruit_cost: int = 1
@export var villager_scene: PackedScene
@export var spawn_parent_path: NodePath
@export var home_target_path: NodePath

@onready var prompt_label: Label = $PromptLabel
@onready var spawn_point: Marker2D = $SpawnPoint

var _player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ResourceManager.coins_changed.connect(_on_coins_changed)
	_refresh_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_try_recruit()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(GameGroups.PLAYER):
		_player_in_range = true
		_refresh_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(GameGroups.PLAYER):
		_player_in_range = false
		_refresh_prompt()

func _on_coins_changed(_before_amount: int, _after_amount: int, _delta_amount: int) -> void:
	if _player_in_range:
		_refresh_prompt()

func _try_recruit() -> void:
	if villager_scene == null:
		push_warning("RecruitCamp has no villager_scene assigned.")
		return

	if not ResourceManager.spend_coins(recruit_cost):
		_refresh_prompt()
		return

	var villager_node: Node = villager_scene.instantiate()
	if not villager_node is Node2D:
		villager_node.queue_free()
		ResourceManager.add_coins(recruit_cost)
		push_warning("RecruitCamp villager_scene must instantiate a Node2D.")
		return

	var villager: Node2D = villager_node as Node2D
	villager.global_position = spawn_point.global_position
	_get_spawn_parent().add_child(villager)

	if villager.has_method("set_home_position"):
		villager.call("set_home_position", _get_home_position())

	recruited.emit(villager)
	_refresh_prompt()

func _get_spawn_parent() -> Node:
	if spawn_parent_path != NodePath(""):
		var spawn_parent: Node = get_node_or_null(spawn_parent_path)
		if spawn_parent != null:
			return spawn_parent

	return get_parent()

func _get_home_position() -> Vector2:
	if home_target_path != NodePath(""):
		var home_target: Node2D = get_node_or_null(home_target_path) as Node2D
		if home_target != null:
			return home_target.global_position

	return global_position

func _refresh_prompt() -> void:
	prompt_label.visible = _player_in_range

	if not _player_in_range:
		return

	if ResourceManager.can_afford(recruit_cost):
		prompt_label.text = "E - Recruit (%d coin)" % recruit_cost
	else:
		prompt_label.text = "Need %d coin" % recruit_cost
