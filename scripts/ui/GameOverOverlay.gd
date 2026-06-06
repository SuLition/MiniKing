extends Control

@export var game_manager_path: NodePath

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var hint_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HintLabel

var _game_manager: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_game_manager = get_node_or_null(game_manager_path)
	if _game_manager == null:
		push_warning("GameOverOverlay has no valid GameManager path.")
		return

	if _game_manager.has_signal("game_over"):
		_game_manager.connect("game_over", Callable(self, "_on_game_over"))

func _on_game_over() -> void:
	title_label.text = "GAME OVER"
	hint_label.text = "金币被搜刮一空 — 按 R 重开"
	visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_R:
			if _game_manager != null and _game_manager.has_method("restart"):
				_game_manager.call("restart")
