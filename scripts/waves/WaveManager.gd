extends Node

@export var time_manager_path: NodePath
@export var enemy_parent_path: NodePath
@export var left_spawn_path: NodePath
@export var right_spawn_path: NodePath
@export var target_path: NodePath
@export var greed_scene: PackedScene
@export var greed_per_side: int = 1
@export var greed_per_side_per_day: int = 1
@export var night_summary_duration: float = 3.0

var _time_manager: Node = null
var _spawned_for_day: int = 0
var _summary_label: Label = null
var _summary_timer: float = 0.0

func _ready() -> void:
	_time_manager = get_node_or_null(time_manager_path)
	if _time_manager == null:
		push_warning("WaveManager has no valid TimeManager path.")
		return

	if _time_manager.has_signal("phase_changed"):
		_time_manager.connect("phase_changed", Callable(self, "_on_phase_changed"))

	_create_summary_ui()

func _process(delta: float) -> void:
	if _summary_timer <= 0.0 or _summary_label == null:
		return
	_summary_timer -= delta
	if _summary_timer <= 0.0:
		_summary_label.visible = false

func _create_summary_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_summary_label = Label.new()
	_summary_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override("font_size", 48)
	_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_label.visible = false
	canvas.add_child(_summary_label)

func _on_phase_changed(phase_name: StringName, day_count: int, _seconds_remaining: int, _phase_duration: int) -> void:
	if phase_name == &"Night":
		if _spawned_for_day != day_count:
			_spawned_for_day = day_count
			_spawn_night_wave(day_count)
	elif phase_name == &"Dawn":
		_clear_enemies()
		_show_night_summary(day_count)

func _clear_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("greed"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func _show_night_summary(day_count: int) -> void:
	if _summary_label == null:
		return
	_summary_label.text = "第 %d 夜 — 存活！" % day_count
	_summary_label.visible = true
	_summary_timer = night_summary_duration

func _spawn_night_wave(day_count: int) -> void:
	var per_side: int = max(greed_per_side + greed_per_side_per_day * max(day_count - 1, 0), 0)
	for index in range(per_side):
		_spawn_greed(_get_marker_position(left_spawn_path) + Vector2(index * 28.0, 0.0))
		_spawn_greed(_get_marker_position(right_spawn_path) + Vector2(-index * 28.0, 0.0))

func _spawn_greed(spawn_position: Vector2) -> void:
	if greed_scene == null:
		push_warning("WaveManager has no greed_scene assigned.")
		return

	var greed_node: Node = greed_scene.instantiate()
	if not greed_node is Node2D:
		greed_node.queue_free()
		push_warning("WaveManager greed_scene must instantiate a Node2D.")
		return

	var greed: Node2D = greed_node as Node2D
	_get_enemy_parent().add_child(greed)
	greed.global_position = spawn_position

	if greed.has_method("set_target_position"):
		greed.call("set_target_position", _get_marker_position(target_path))

func _get_enemy_parent() -> Node:
	if enemy_parent_path != NodePath(""):
		var enemy_parent: Node = get_node_or_null(enemy_parent_path)
		if enemy_parent != null:
			return enemy_parent

	return get_parent()

func _get_marker_position(marker_path: NodePath) -> Vector2:
	if marker_path != NodePath(""):
		var marker: Node2D = get_node_or_null(marker_path) as Node2D
		if marker != null:
			return marker.global_position

	return Vector2.ZERO
