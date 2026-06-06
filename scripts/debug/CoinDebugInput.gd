extends Node

@export var add_amount: int = 1
@export var spend_amount: int = 1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_add_coin"):
		ResourceManager.add_coins(add_amount)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_spend_coin"):
		ResourceManager.spend_coins(spend_amount)
		get_viewport().set_input_as_handled()
