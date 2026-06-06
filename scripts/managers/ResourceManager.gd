extends Node

signal coins_changed(before_amount: int, after_amount: int, delta_amount: int)

@export var starting_coins: int = 10

var _coins: int = 0

func _ready() -> void:
	reset_coins(starting_coins)

func add_coins(amount: int) -> void:
	if amount <= 0:
		return

	_set_coins(_coins + amount)

func spend_coins(amount: int) -> bool:
	if amount <= 0 or _coins < amount:
		return false

	_set_coins(_coins - amount)
	return true

func can_afford(amount: int) -> bool:
	return amount >= 0 and _coins >= amount

func get_coins() -> int:
	return _coins

func reset_coins(amount: int = -1) -> void:
	if amount < 0:
		amount = starting_coins

	_set_coins(max(amount, 0))

func _set_coins(amount: int) -> void:
	var before_amount: int = _coins
	var after_amount: int = max(amount, 0)

	if before_amount == after_amount:
		return

	_coins = after_amount
	coins_changed.emit(before_amount, after_amount, after_amount - before_amount)
