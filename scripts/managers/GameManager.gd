extends Node

signal game_over

var _is_game_over: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ResourceManager.coins_changed.connect(_on_coins_changed)

func _on_coins_changed(_before_amount: int, after_amount: int, _delta_amount: int) -> void:
	if _is_game_over:
		return

	if after_amount <= 0:
		_trigger_game_over()

func _trigger_game_over() -> void:
	_is_game_over = true
	get_tree().paused = true
	game_over.emit()

func restart() -> void:
	get_tree().paused = false
	_is_game_over = false
	get_tree().reload_current_scene()

func is_game_over() -> bool:
	return _is_game_over
