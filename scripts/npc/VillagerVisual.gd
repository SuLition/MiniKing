extends Node

# Villager 视觉表现。
# 颜色由 _tool_type 决定（无工具/builder/archer），角色标签同步。
# state_changed 当前不影响外观，但保留以便未来加动画。

@onready var body: Polygon2D = $"../Body"
@onready var role_label: Label = $"../RoleLabel"

func _ready() -> void:
	var villager: Node = get_parent()
	if villager == null:
		return

	if villager.has_signal("tool_changed"):
		villager.connect("tool_changed", Callable(self, "_on_tool_changed"))

	if villager.has_method("get_tool_type"):
		_on_tool_changed(villager.call("get_tool_type"))
	else:
		_on_tool_changed(&"")

func _on_tool_changed(tool_type: StringName) -> void:
	match tool_type:
		&"builder":
			body.color = Color(0.9, 0.58, 0.18, 1)
			role_label.text = "Builder"
			role_label.visible = true
		&"archer":
			body.color = Color(0.55, 0.78, 0.4, 1)
			role_label.text = "Archer"
			role_label.visible = true
		_:
			body.color = Color(0.35, 0.62, 0.95, 1)
			role_label.text = "Villager"
			role_label.visible = false
