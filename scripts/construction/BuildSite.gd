extends Area2D

# 建造点。玩家投币后向 TaskBoard 发布 CONSTRUCTION 任务。
# Builder NPC 到达后由本节点接管，定时完成并生成 Wall。
#
# 注：本节点不再持有 _state 中的 ORDERED/ASSIGNED 区分——状态由 task 是否在 board 上 / 是否 claimed 隐式表达。
# 本节点只关心 EMPTY / WAITING / BUILDING / BUILT。

enum State {
	EMPTY,
	WAITING,   # 任务已发布，等 NPC 来
	BUILDING,
	BUILT,
}

@export var build_cost: int = 3
@export var build_time: float = 1.5
@export var wall_scene: PackedScene
@export var wall_parent_path: NodePath

@onready var prompt_label: Label = $PromptLabel
@onready var build_marker: Marker2D = $BuildMarker
@onready var work_marker: Marker2D = $WorkMarker
@onready var marker: Polygon2D = $Marker

var _player_in_range: bool = false
var _state: State = State.EMPTY
var _current_task: Task = null

func _ready() -> void:
	add_to_group(GameGroups.TASK_PROVIDER)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ResourceManager.coins_changed.connect(_on_coins_changed)
	_refresh_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_try_order_construction()
		get_viewport().set_input_as_handled()

# ---- Task provider contract ----

func start_work(claimant: Node, task: Task) -> bool:
	if _state != State.WAITING or task != _current_task:
		return false

	_state = State.BUILDING
	_refresh_prompt()
	_complete_after_delay(claimant, task)
	return true

# ---- Internal ----

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

func _try_order_construction() -> void:
	if _state != State.EMPTY:
		_refresh_prompt()
		return

	if not ResourceManager.spend_coins(build_cost):
		_refresh_prompt()
		return

	var task: Task = Task.new()
	task.kind = Task.Kind.CONSTRUCTION
	task.position = work_marker.global_position
	task.provider = self
	TaskBoard.post_task(task)

	_current_task = task
	_state = State.WAITING
	_refresh_prompt()

func _complete_after_delay(claimant: Node, task: Task) -> void:
	await get_tree().create_timer(build_time).timeout

	if _state != State.BUILDING:
		return

	_spawn_wall()
	_state = State.BUILT
	_current_task = null
	_refresh_prompt()

	if claimant != null and is_instance_valid(claimant) and claimant.has_method("finish_work"):
		claimant.call("finish_work")

	TaskBoard.complete_task(task)

func _spawn_wall() -> void:
	if wall_scene == null:
		push_warning("BuildSite has no wall_scene assigned.")
		return

	var wall_node: Node = wall_scene.instantiate()
	if not wall_node is Node2D:
		wall_node.queue_free()
		push_warning("BuildSite wall_scene must instantiate a Node2D.")
		return

	var wall: Node2D = wall_node as Node2D
	_get_wall_parent().add_child(wall)
	wall.global_position = build_marker.global_position

func _get_wall_parent() -> Node:
	if wall_parent_path != NodePath(""):
		var wall_parent: Node = get_node_or_null(wall_parent_path)
		if wall_parent != null:
			return wall_parent

	return get_parent()

func _refresh_prompt() -> void:
	marker.visible = _state != State.BUILT
	prompt_label.visible = _player_in_range or _state == State.WAITING or _state == State.BUILDING

	match _state:
		State.EMPTY:
			marker.color = Color(0.45, 0.45, 0.45, 1)
			if _player_in_range and ResourceManager.can_afford(build_cost):
				prompt_label.text = "E - Build Wall (%d coins)" % build_cost
			elif _player_in_range:
				prompt_label.text = "Need %d coins" % build_cost
		State.WAITING:
			marker.color = Color(0.72, 0.62, 0.22, 1)
			prompt_label.text = "Waiting for builder"
		State.BUILDING:
			marker.color = Color(0.9, 0.58, 0.18, 1)
			prompt_label.text = "Building..."
		State.BUILT:
			marker.color = Color(0.3, 0.6, 0.32, 1)
			prompt_label.visible = _player_in_range
			prompt_label.text = "Wall built"
