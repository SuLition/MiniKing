extends Control

@export var time_manager_path: NodePath

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var timer_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TimerLabel
@onready var phase_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/PhaseBar

var _time_manager: Node = null

func _ready() -> void:
	_time_manager = get_node_or_null(time_manager_path)
	if _time_manager == null:
		push_warning("DayNightIndicator has no valid TimeManager path.")
		return

	if _time_manager.has_signal("time_tick"):
		_time_manager.connect("time_tick", Callable(self, "_on_time_tick"))

	_refresh_from_manager()

func _on_time_tick(phase_name: StringName, day_count: int, seconds_remaining: int, phase_duration: int) -> void:
	_refresh(phase_name, day_count, seconds_remaining, phase_duration)

func _refresh_from_manager() -> void:
	if not _time_manager.has_method("get_phase_name"):
		return

	var phase_name: StringName = StringName(_time_manager.call("get_phase_name"))
	var day_count: int = int(_time_manager.call("get_day_count"))
	var seconds_remaining: int = int(_time_manager.call("get_seconds_remaining"))
	var phase_duration: int = int(_time_manager.call("get_phase_duration"))
	_refresh(phase_name, day_count, seconds_remaining, phase_duration)

func _refresh(phase_name: StringName, day_count: int, seconds_remaining: int, phase_duration: int) -> void:
	title_label.text = "Day %d - %s" % [day_count, String(phase_name)]
	timer_label.text = "%ds remaining" % seconds_remaining

	phase_bar.max_value = max(phase_duration, 1)
	phase_bar.value = clamp(phase_duration - seconds_remaining, 0, phase_duration)
