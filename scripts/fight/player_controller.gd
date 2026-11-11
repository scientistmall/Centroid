class_name PlayerController
extends RefCounted
## Reads keyboard / touch-control input actions.


func get_input(_f: Fighter, _delta: float) -> Dictionary:
	return {
		"move": Input.get_axis("move_left", "move_right"),
		"jump": Input.is_action_just_pressed("jump"),
		"light": Input.is_action_just_pressed("attack_light"),
		"heavy": Input.is_action_just_pressed("attack_heavy"),
		"block": Input.is_action_pressed("block"),
		"power_1": Input.is_action_just_pressed("power_1"),
		"power_2": Input.is_action_just_pressed("power_2"),
	}
