extends CanvasLayer

@export var toggle_action: StringName = &"debug_menu"
@export var debug_actions_path: NodePath

var _actions: DebugActions = null
var _status_label: Label = null

func _ready() -> void:
	layer = 200
	_actions = get_node_or_null(debug_actions_path) as DebugActions
	visible = false
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		visible = not visible
		_update_status()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if visible:
		_update_status()

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.offset_left = 24.0
	panel.offset_top = 120.0
	panel.offset_right = 364.0
	panel.offset_bottom = 650.0
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title: Label = Label.new()
	title.text = "调试菜单 (P)"
	root.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	var coin_toggle: CheckBox = CheckBox.new()
	coin_toggle.text = "无限金币"
	coin_toggle.toggled.connect(_on_infinite_coins_toggled)
	root.add_child(coin_toggle)

	_add_button(root, "增加 10 金币", _on_add_coins_pressed)
	_add_button(root, "增加 50 金币", _on_add_many_coins_pressed)
	_add_button(root, "重置金币", _on_reset_coins_pressed)
	_add_separator(root)
	_add_button(root, "生成村民", _on_spawn_villager_pressed)
	_add_profession_buttons(root)
	_add_button(root, "左侧生成贪婪怪", _on_spawn_greed_left_pressed)
	_add_button(root, "右侧生成贪婪怪", _on_spawn_greed_right_pressed)
	_add_separator(root)
	_add_button(root, "清理敌人", _on_clear_enemies_pressed)
	_add_button(root, "清理村民", _on_clear_villagers_pressed)
	_add_button(root, "清理任务", _on_clear_tasks_pressed)
	_add_separator(root)
	_add_button(root, "暂停 / 恢复时间", _on_toggle_time_pressed)
	_add_button(root, "重启昼夜循环", _on_restart_time_pressed)

func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _add_separator(parent: VBoxContainer) -> void:
	var separator: HSeparator = HSeparator.new()
	parent.add_child(separator)

func _add_profession_buttons(parent: VBoxContainer) -> void:
	if _actions == null:
		return

	for profession: ProfessionDefinition in _actions.get_spawnable_professions():
		if profession == null:
			continue

		var label: String = profession.display_name
		if label.is_empty():
			label = str(profession.id)
		_add_button(parent, "生成" + label, _on_spawn_profession_pressed.bind(profession))

func _on_infinite_coins_toggled(enabled: bool) -> void:
	if _actions != null:
		_actions.set_infinite_coins_enabled(enabled)
	_update_status()

func _on_add_coins_pressed() -> void:
	if _actions != null:
		_actions.add_coins()

func _on_add_many_coins_pressed() -> void:
	if _actions != null:
		_actions.add_many_coins()

func _on_reset_coins_pressed() -> void:
	if _actions != null:
		_actions.reset_coins()

func _on_spawn_villager_pressed() -> void:
	if _actions != null:
		_actions.spawn_villager()

func _on_spawn_profession_pressed(profession: ProfessionDefinition) -> void:
	if _actions != null:
		_actions.spawn_profession(profession)

func _on_spawn_greed_left_pressed() -> void:
	if _actions != null:
		_actions.spawn_greed_left()

func _on_spawn_greed_right_pressed() -> void:
	if _actions != null:
		_actions.spawn_greed_right()

func _on_clear_enemies_pressed() -> void:
	if _actions != null:
		_actions.clear_enemies()

func _on_clear_villagers_pressed() -> void:
	if _actions != null:
		_actions.clear_villagers()

func _on_clear_tasks_pressed() -> void:
	if _actions != null:
		_actions.clear_tasks()

func _on_toggle_time_pressed() -> void:
	if _actions != null:
		_actions.toggle_time_pause()

func _on_restart_time_pressed() -> void:
	if _actions != null:
		_actions.restart_time_cycle()

func _update_status() -> void:
	if _status_label == null:
		return

	if _actions == null:
		_status_label.text = "DebugActions 节点未配置。"
		return

	var status: Dictionary = _actions.get_status()
	_status_label.text = "金币: %d\n村民: %d\n敌人: %d\n任务: %d\n无限金币: %s\n时间暂停: %s" % [
		int(status["coins"]),
		int(status["villagers"]),
		int(status["enemies"]),
		int(status["tasks"]),
		_bool_text(bool(status["infinite_coins"])),
		_bool_text(bool(status["time_paused"])),
	]

func _bool_text(value: bool) -> String:
	if value:
		return "是"
	return "否"
