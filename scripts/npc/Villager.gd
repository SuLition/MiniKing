extends CharacterBody2D

# Villager 主行为脚本。
#
# 状态机：
#   IDLE    — poll 找活；超过 idle_to_wander_delay 没找到 → WANDER
#             非 archer：poll TaskBoard 找 TOOL_PICKUP / CONSTRUCTION
#             archer：扫描射程内的 Greed → 找到则进 COMBAT
#   WANDER  — 在 home_position ±wander_radius 范围内随机漫步；同样在 poll 周期里找活
#   SEEK    — 走向 _current_task.position；到达后 → WORK
#   WORK    — 把控制权交给 task.provider，等 provider 回调 finish_work() 后 → IDLE
#   COMBAT  — 仅 archer 进入：站定，按 attack_interval 射箭；扫描不到 Greed 时退回 IDLE
#
# 工具能力（_tool_type）决定 IDLE / WANDER 周期里"找活"的分支：
#   ""        → 找 TOOL_PICKUP
#   "builder" → 找 CONSTRUCTION
#   "archer"  → 不走 TaskBoard，扫敌；命中即进 COMBAT
#
# 对外接口：
#   set_home_position(p)  — 设定漫步中心，不强制移动
#   equip_tool(t)         — 由 task provider 在 start_work 中调用
#   finish_work()         — 由 task provider 在工作完成时调用
#
# 设计约束：
#   - 不持有 HammerStand / BuildSite 等具体类型引用
#   - 不主动联系任何 Manager（不存在 JobManager / ConstructionManager）
#   - 全部任务交互走 TaskBoard
#   - COMBAT 内的战斗不知道 TaskBoard 存在

signal state_changed(state_name: StringName)
signal tool_changed(tool_type: StringName)
signal hp_changed(current_hp: int, max_hp: int)
signal destroyed

const ARROW_SCENE: PackedScene = preload("res://scenes/combat/Arrow.tscn")

enum State {
	IDLE,
	WANDER,
	SEEK,
	WORK,
	COMBAT,
}

@export var walk_speed: float = 70.0
@export var wander_speed_ratio: float = 0.5
@export var arrival_distance: float = 8.0
@export var poll_interval: float = 0.5
@export var idle_to_wander_delay: float = 2.0
@export var wander_radius: float = 60.0
@export var wander_rest_min: float = 0.6
@export var wander_rest_max: float = 1.4
@export var max_hp: int = 2

@export_group("Archer")
@export var attack_range: float = 220.0
@export var attack_interval: float = 1.2
@export var arrow_spawn_offset: Vector2 = Vector2(0.0, -30.0)

var hp: int = 2
var _home_position: Vector2 = Vector2.ZERO
var _has_home: bool = false
var _state: State = State.IDLE
var _tool_type: StringName = &""
var _current_task: Task = null

var _poll_timer: float = 0.0
var _idle_time: float = 0.0
var _wander_target_x: float = 0.0
var _wander_rest_timer: float = 0.0
var _attack_timer: float = 0.0

func _ready() -> void:
	add_to_group("villager")
	add_to_group("damageable")
	hp = max_hp
	_update_damage_visual()
	_set_state(State.IDLE)
	tool_changed.emit(_tool_type)

# ---- Public API ----

func apply_damage(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return

	hp = max(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	_update_damage_visual()

	if hp == 0:
		_handle_death()

func get_hp() -> int:
	return hp

func set_home_position(home_position: Vector2) -> void:
	_home_position = home_position
	_has_home = true

func get_tool_type() -> StringName:
	return _tool_type

func equip_tool(tool_type: StringName) -> void:
	if _tool_type == tool_type:
		return
	_tool_type = tool_type
	tool_changed.emit(_tool_type)

func finish_work() -> void:
	# Provider 通知本 NPC 工作完成。释放当前任务，回 IDLE。
	# 持弓的工人也走 IDLE → 由 IDLE 周期 poll 自动决定漫步或战斗。
	_current_task = null
	_set_state(State.IDLE)

# ---- Physics loop ----

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WANDER:
			_process_wander(delta)
		State.SEEK:
			_process_seek(delta)
		State.WORK:
			_stop_horizontal_motion(delta)
		State.COMBAT:
			_process_combat(delta)

	move_and_slide()

# ---- State handlers ----

func _process_idle(delta: float) -> void:
	_stop_horizontal_motion(delta)
	_idle_time += delta
	_poll_timer -= delta

	if _poll_timer <= 0.0:
		_poll_timer = poll_interval
		if _try_engage_work_or_combat():
			return

	if _idle_time >= idle_to_wander_delay and _has_home:
		_enter_wander()

func _process_wander(delta: float) -> void:
	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = poll_interval
		if _try_engage_work_or_combat():
			return

	if _wander_rest_timer > 0.0:
		_stop_horizontal_motion(delta)
		_wander_rest_timer -= delta
		if _wander_rest_timer <= 0.0:
			_pick_new_wander_target()
		return

	var x_distance: float = _wander_target_x - global_position.x
	if absf(x_distance) <= arrival_distance:
		_stop_horizontal_motion(delta)
		_wander_rest_timer = randf_range(wander_rest_min, wander_rest_max)
		return

	velocity.x = signf(x_distance) * walk_speed * wander_speed_ratio

func _process_seek(delta: float) -> void:
	if _current_task == null:
		_set_state(State.IDLE)
		return

	var x_distance: float = _current_task.position.x - global_position.x
	if absf(x_distance) <= arrival_distance:
		_stop_horizontal_motion(delta)
		_enter_work()
		return

	velocity.x = signf(x_distance) * walk_speed

func _process_combat(delta: float) -> void:
	_stop_horizontal_motion(delta)
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return

	var target: Node2D = _find_nearest_greed_in_range()
	if target == null:
		# 没有目标，退回 IDLE；IDLE 周期会自然进入漫步循环
		_set_state(State.IDLE)
		return

	_fire_arrow_at(target.global_position)
	_attack_timer = max(attack_interval, 0.1)

func _try_engage_work_or_combat() -> bool:
	if _tool_type == &"archer":
		return _try_engage_combat()
	return _try_claim_task()

func _try_engage_combat() -> bool:
	var target: Node2D = _find_nearest_greed_in_range()
	if target == null:
		return false

	_idle_time = 0.0
	_attack_timer = 0.0
	_set_state(State.COMBAT)
	return true

# ---- Combat ----

func _find_nearest_greed_in_range() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for greed_node in get_tree().get_nodes_in_group("greed"):
		if not greed_node is Node2D:
			continue

		var greed: Node2D = greed_node as Node2D
		var distance: float = global_position.distance_to(greed.global_position)
		if distance > attack_range:
			continue
		if distance < nearest_distance:
			nearest = greed
			nearest_distance = distance

	return nearest

func _fire_arrow_at(target_position: Vector2) -> void:
	if ARROW_SCENE == null:
		return

	var arrow_node: Node = ARROW_SCENE.instantiate()
	if not arrow_node is Node2D:
		arrow_node.queue_free()
		return

	var arrow: Node2D = arrow_node as Node2D
	get_parent().add_child(arrow)
	arrow.global_position = global_position + arrow_spawn_offset

	if arrow.has_method("launch"):
		arrow.call("launch", target_position)

# ---- State transitions ----

func _try_claim_task() -> bool:
	if not TaskBoard.has_method("claim_nearest"):
		return false

	var claimed: Task = TaskBoard.claim_nearest(Callable(self, "_can_do_task"), global_position)
	if claimed == null:
		return false

	_current_task = claimed
	_idle_time = 0.0
	_set_state(State.SEEK)
	return true

func _can_do_task(task: Task) -> bool:
	if task == null:
		return false

	match _tool_type:
		&"":
			return task.kind == Task.Kind.TOOL_PICKUP
		&"builder":
			return task.kind == Task.Kind.CONSTRUCTION
		_:
			return false

func _enter_wander() -> void:
	_set_state(State.WANDER)
	_pick_new_wander_target()

func _pick_new_wander_target() -> void:
	if not _has_home:
		_wander_target_x = global_position.x
	else:
		_wander_target_x = _home_position.x + randf_range(-wander_radius, wander_radius)
	_wander_rest_timer = 0.0

func _enter_work() -> void:
	_set_state(State.WORK)

	if _current_task == null:
		_abort_current_task()
		return

	var provider: Node = _current_task.provider
	if provider == null or not is_instance_valid(provider) or not provider.has_method("start_work"):
		_abort_current_task()
		return

	var ok: Variant = provider.call("start_work", self, _current_task)
	if not bool(ok):
		_abort_current_task()

func _abort_current_task() -> void:
	if _current_task != null:
		TaskBoard.release_task(_current_task)
		_current_task = null
	_set_state(State.IDLE)

func _handle_death() -> void:
	if _current_task != null and _state != State.WORK:
		TaskBoard.release_task(_current_task)
	_current_task = null
	destroyed.emit()
	queue_free()

# ---- Motion helpers ----

func _stop_horizontal_motion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, walk_speed * 4.0 * delta)

func _update_damage_visual() -> void:
	var hp_ratio: float = 1.0
	if max_hp > 0:
		hp_ratio = clamp(float(hp) / float(max_hp), 0.0, 1.0)

	var damage_t: float = 1.0 - hp_ratio
	modulate = Color(1.0, lerp(1.0, 0.55, damage_t), lerp(1.0, 0.55, damage_t), 1.0)

# ---- State bookkeeping ----

func _set_state(next_state: State) -> void:
	if _state == next_state:
		return

	_state = next_state

	if _state == State.IDLE:
		_idle_time = 0.0
		_poll_timer = 0.0

	state_changed.emit(_get_state_name())

func _get_state_name() -> StringName:
	match _state:
		State.IDLE:
			return &"idle"
		State.WANDER:
			return &"wander"
		State.SEEK:
			return &"seek"
		State.WORK:
			return &"work"
		State.COMBAT:
			return &"combat"
		_:
			return &"unknown"
