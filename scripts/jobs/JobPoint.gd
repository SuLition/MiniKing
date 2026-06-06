extends Area2D

# 工具购买点（如 HammerStand、BowStand）。
# 玩家按 E 花金币后，向 TaskBoard 发布一个 TOOL_PICKUP 任务，等待 NPC 自取。
# 不再持有 NPC 引用，不再监听任何 NPC 信号。

@export var tool_type: StringName = &"builder"
@export var display_name: String = "Hammer"
@export var cost: int = 2

@onready var prompt_label: Label = $PromptLabel
@onready var pickup_point: Marker2D = $ToolPickupPoint

var _player_in_range: bool = false
var _pending_count: int = 0

func _ready() -> void:
	add_to_group("task_provider")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ResourceManager.coins_changed.connect(_on_coins_changed)
	_refresh_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_try_buy_tool()
		get_viewport().set_input_as_handled()

# ---- Task provider contract ----

func start_work(claimant: Node, task: Task) -> bool:
	if claimant == null or not claimant.has_method("equip_tool"):
		return false

	claimant.call("equip_tool", tool_type)

	if claimant.has_method("finish_work"):
		claimant.call("finish_work")

	TaskBoard.complete_task(task)
	_pending_count = max(_pending_count - 1, 0)
	_refresh_prompt()
	return true

# ---- Internal ----

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = true
		_refresh_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = false
		_refresh_prompt()

func _on_coins_changed(_before_amount: int, _after_amount: int, _delta_amount: int) -> void:
	if _player_in_range:
		_refresh_prompt()

func _try_buy_tool() -> void:
	if not ResourceManager.spend_coins(cost):
		_refresh_prompt()
		return

	var task: Task = Task.new()
	task.kind = Task.Kind.TOOL_PICKUP
	task.position = pickup_point.global_position
	task.provider = self
	task.payload = {"tool_type": tool_type}
	TaskBoard.post_task(task)

	_pending_count += 1
	_refresh_prompt()

func _refresh_prompt() -> void:
	prompt_label.visible = _player_in_range or _pending_count > 0

	if _pending_count > 0:
		prompt_label.text = "%s ready: %d" % [display_name, _pending_count]
	elif _player_in_range and ResourceManager.can_afford(cost):
		prompt_label.text = "E - Buy %s (%d coins)" % [display_name, cost]
	elif _player_in_range:
		prompt_label.text = "Need %d coins" % cost
