class_name PlayerController
extends RefCounted
## Reads keyboard / touch-control input actions (MCOC scheme; the player is always on the left):
##   right / D (or the touch swipe toward) .. "forward": medium attack in range, dash when far
##   left / A (or the touch swipe back) ..... dash back
##   J light, K heavy, L/S/down block (held), U/I/O power 1-3, P highest power


func get_input(_f: Fighter, _delta: float) -> Dictionary:
	return {
		"forward": Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("attack_medium"),
		"dash_back": Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("dash_back"),
		"light": Input.is_action_just_pressed("attack_light"),
		"heavy": Input.is_action_just_pressed("attack_heavy"),
		"block": Input.is_action_pressed("block"),
		"power_1": Input.is_action_just_pressed("power_1"),
		"power_2": Input.is_action_just_pressed("power_2"),
		"power_3": Input.is_action_just_pressed("power_3"),
		"power": Input.is_action_just_pressed("power"),   # touch: tap the power gauge
	}
