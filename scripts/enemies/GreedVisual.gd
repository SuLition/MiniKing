class_name GreedVisual
extends AnimatedSprite2D

signal death_animation_finished

@export var idle_animations: Array[StringName] = [&"idle", &"Idel"]
@export var walk_animation: StringName = &"walk"
@export var hurt_animation: StringName = &"hurt"
@export var death_animation: StringName = &"death"
@export var attack_animations: Array[StringName] = [&"attack1", &"attack2", &"attack3", &"attack4"]
@export var fallback_attack_animation: StringName = &"sneer"
@export var movement_threshold: float = 1.0
@export var faces_left_by_default: bool = true

var _base_animation: StringName = &""
var _one_shot_active: bool = false
var _dead: bool = false
var _attack_index: int = 0

func _ready() -> void:
	_configure_one_shot_animations()
	animation_finished.connect(_on_animation_finished)
	play_idle()

func play_idle() -> void:
	_play_base(_get_idle_animation())

func update_locomotion(horizontal_velocity: float) -> void:
	if _dead:
		return

	if absf(horizontal_velocity) > movement_threshold:
		_update_facing(horizontal_velocity)
		_play_base(walk_animation)
	else:
		_play_base(_get_idle_animation())

func play_attack() -> void:
	if _dead:
		return

	var attack_animation: StringName = _next_attack_animation()
	if attack_animation == &"" and _has_animation(fallback_attack_animation):
		attack_animation = fallback_attack_animation

	if attack_animation != &"":
		_play_one_shot(attack_animation)

func play_hurt() -> void:
	if _dead:
		return

	if _has_animation(hurt_animation):
		_play_one_shot(hurt_animation)

func play_death() -> void:
	_dead = true
	if _has_animation(death_animation):
		_play_one_shot(death_animation)
	else:
		death_animation_finished.emit.call_deferred()

func _configure_one_shot_animations() -> void:
	if sprite_frames == null:
		return

	if _has_animation(hurt_animation):
		sprite_frames.set_animation_loop(hurt_animation, false)
	if _has_animation(death_animation):
		sprite_frames.set_animation_loop(death_animation, false)

	for attack_animation: StringName in attack_animations:
		if _has_animation(attack_animation):
			sprite_frames.set_animation_loop(attack_animation, false)
	if _has_animation(fallback_attack_animation):
		sprite_frames.set_animation_loop(fallback_attack_animation, false)

func _play_base(animation_name: StringName) -> void:
	if _one_shot_active or animation_name == &"" or not _has_animation(animation_name):
		return

	_base_animation = animation_name
	if animation != animation_name or not is_playing():
		play(animation_name)

func _play_one_shot(animation_name: StringName) -> void:
	if animation_name == &"" or not _has_animation(animation_name):
		return

	_one_shot_active = true
	play(animation_name)
	frame = 0

func _on_animation_finished() -> void:
	if _dead:
		death_animation_finished.emit()
		return

	if not _one_shot_active:
		return

	_one_shot_active = false
	_play_base(_base_animation)

func _next_attack_animation() -> StringName:
	if attack_animations.is_empty():
		return &""

	for offset: int in range(attack_animations.size()):
		var index: int = (_attack_index + offset) % attack_animations.size()
		var candidate: StringName = attack_animations[index]
		if _has_animation(candidate):
			_attack_index = index + 1
			return candidate

	return &""

func _get_idle_animation() -> StringName:
	for idle_animation: StringName in idle_animations:
		if _has_animation(idle_animation):
			return idle_animation
	return &""

func _has_animation(animation_name: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(animation_name)

func _update_facing(horizontal_velocity: float) -> void:
	if faces_left_by_default:
		flip_h = horizontal_velocity > 0.0
	else:
		flip_h = horizontal_velocity < 0.0
