extends Node

# Villager 视觉表现。
# 颜色优先由 ProfessionDefinition 决定；_tool_type 只用于旧路径兼容。
# state_changed 当前不影响外观，但保留以便未来加动画。

@onready var body: Polygon2D = $"../Body"
@onready var role_label: Label = $"../RoleLabel"

func _ready() -> void:
	var villager: Node = get_parent()
	if villager == null:
		return

	if villager.has_signal("profession_changed"):
		villager.connect("profession_changed", Callable(self, "_on_profession_changed"))

	if villager.has_signal("tool_changed"):
		villager.connect("tool_changed", Callable(self, "_on_tool_changed"))

	if villager.has_method("get_profession"):
		_on_profession_changed(villager.call("get_profession"))
	elif villager.has_method("get_tool_type"):
		_on_tool_changed(villager.call("get_tool_type"))
	else:
		_on_tool_changed(&"")

func _on_profession_changed(profession: ProfessionDefinition) -> void:
	if profession == null:
		_on_tool_changed(&"")
		return

	body.color = profession.body_color
	role_label.text = profession.display_name
	role_label.visible = profession.show_role_label

func _on_tool_changed(tool_type: StringName) -> void:
	if _has_profession():
		return

	match tool_type:
		&"builder":
			body.color = Color(0.9, 0.58, 0.18, 1)
			role_label.text = "建造者"
			role_label.visible = true
		&"archer":
			body.color = Color(0.55, 0.78, 0.4, 1)
			role_label.text = "弓箭手"
			role_label.visible = true
		_:
			body.color = Color(0.35, 0.62, 0.95, 1)
			role_label.text = "村民"
			role_label.visible = false

func _has_profession() -> bool:
	var villager: Node = get_parent()
	if villager == null or not villager.has_method("get_profession"):
		return false
	return villager.call("get_profession") != null
