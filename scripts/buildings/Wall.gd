extends StaticBody2D

signal hp_changed(current_hp: int, max_hp: int)
signal destroyed

@export var max_hp: int = 1

@onready var body: Polygon2D = $Body

var hp: int = 1

func _ready() -> void:
	add_to_group("wall")
	add_to_group("damageable")
	hp = max_hp
	_update_visual()

func apply_damage(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return

	hp = max(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	_update_visual()

	if hp == 0:
		destroyed.emit()
		queue_free()

func get_hp() -> int:
	return hp

func _update_visual() -> void:
	if body == null:
		return

	var hp_ratio: float = 1.0
	if max_hp > 0:
		hp_ratio = clamp(float(hp) / float(max_hp), 0.0, 1.0)

	body.color = Color(0.42 + (1.0 - hp_ratio) * 0.35, 0.38 * hp_ratio, 0.31 * hp_ratio, 1)
