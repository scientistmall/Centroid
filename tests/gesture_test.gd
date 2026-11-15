extends Node
## Gestures -> actions: tap, hold own side, tap the power gauge, drag, flick, swipe up.
## Events arrive in window pixels; the fight works in viewport pixels.
func _win(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


func _touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = _win(p)
	e.pressed = down
	Input.parse_input_event(e)


func _drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = _win(p)
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _ready() -> void:
	SceneRouter.current = {"type": "fight", "id": "fight01", "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	for i in 600:
		await get_tree().physics_frame
		if a.phase == "fight":
			break
	a.enemy.controller = null
	var tc: TouchControls = a.touch
	var vs := get_viewport().get_visible_rect().size
	var own := Vector2(vs.x * 0.25, vs.y * 0.6)
	var opp := Vector2(vs.x * 0.75, vs.y * 0.6)
	var ok := true
	var seen := {}
	var watch := func():
		for act in ["attack_light", "attack_heavy", "block", "power", "jump", "move_right", "move_left"]:
			if Input.is_action_pressed(act):
				seen[act] = true
	# tap opponent side -> light
	_touch(0, opp, true); await _frames(3); _touch(0, opp, false)
	for k in 3: watch.call(); await get_tree().process_frame
	# hold own side -> block
	_touch(0, own, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300:
		watch.call(); await get_tree().process_frame
	_touch(0, own, false); await _frames(2)
	# holding the opponent's side no longer fires a power
	a.player.energy = 300.0
	_touch(0, opp, true)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await get_tree().process_frame
	_touch(0, opp, false); await _frames(3)
	var no_hold_power: bool = a.player.energy > 299.0 and a.player.state != Fighter.S.POWER
	# tap the power gauge with full bars -> power
	a.player.energy = 300.0
	var e0: float = a.player.energy
	var g: Vector2 = tc.gauge_rect().get_center()
	_touch(0, g, true)
	for k in 4: watch.call(); await get_tree().process_frame
	_touch(0, g, false); await _frames(3)
	var power_fired: bool = a.player.energy < e0 - 1.0 or a.player.state == Fighter.S.POWER
	# drag toward opponent -> move right
	_touch(1, own, true); await _frames(2); _drag(1, own + Vector2(120, 0))
	for k in 5: watch.call(); await get_tree().process_frame
	_touch(1, own + Vector2(120, 0), false); await _frames(2)
	# swipe up -> jump
	_touch(2, own, true); await _frames(1); _drag(2, own + Vector2(0, -150))
	for k in 3: watch.call(); await get_tree().process_frame
	_touch(2, own + Vector2(0, -150), false)
	for act in ["attack_light", "block", "jump", "move_right"]:
		print(("ok   " if seen.has(act) else "FAIL ") + act)
		ok = ok and seen.has(act)
	print(("ok   " if no_hold_power else "FAIL ") + "holding the opponent's side does not fire a power")
	print(("ok   " if power_fired else "FAIL ") + "power fired by tapping the gauge (bars %d -> %d)" % [int(e0), int(a.player.energy)])
	ok = ok and power_fired and no_hold_power
	print("GESTURES: ", "PASS" if ok else "FAIL")
	get_tree().quit()
