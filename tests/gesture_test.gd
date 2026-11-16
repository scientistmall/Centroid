extends Node
## MCOC gestures -> actions: tap, swipe toward / back, hold either half, tap the power gauge.
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
	var own := Vector2(vs.x * 0.25, vs.y * 0.5)
	var opp := Vector2(vs.x * 0.75, vs.y * 0.5)
	var ok := true
	var seen := {}
	var watch := func():
		for act in ["attack_light", "attack_medium", "attack_heavy", "block", "power", "dash_back"]:
			if Input.is_action_pressed(act):
				seen[act] = true
	var expect := func(act: String, what: String) -> void:
		print(("ok   " if seen.has(act) else "FAIL ") + what)
		ok = ok and seen.has(act)
		seen.clear()
	# tap the opponent's half -> light
	_touch(0, opp, true); await _frames(3); _touch(0, opp, false)
	for k in 3: watch.call(); await get_tree().process_frame
	expect.call("attack_light", "tap their half: light attack")
	# hold own half -> block from the first frame
	_touch(0, own, true)
	await _frames(1)
	watch.call()
	expect.call("block", "touch your half: block at once")
	# a slow drift while blocking keeps the block
	for k in 20:
		_drag(0, own + Vector2(-3.0 * k, 0)); await get_tree().process_frame
	var still := Input.is_action_pressed("block")
	print(("ok   " if still else "FAIL ") + "a resting block thumb that drifts keeps blocking")
	ok = ok and still
	_touch(0, own + Vector2(-60, 0), false); await _frames(2)
	# hold the opponent's half -> heavy
	_touch(0, opp, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		watch.call(); await get_tree().process_frame
	_touch(0, opp, false); await _frames(2)
	expect.call("attack_heavy", "hold their half: heavy attack")
	# swipe toward -> medium / dash forward
	_touch(1, own, true); await _frames(1); _drag(1, own + Vector2(160, 0))
	for k in 3: watch.call(); await get_tree().process_frame
	_touch(1, own + Vector2(160, 0), false); await _frames(2)
	expect.call("attack_medium", "swipe toward: medium / dash forward")
	# swipe back -> dash back
	_touch(2, opp, true); await _frames(1); _drag(2, opp - Vector2(160, 0))
	for k in 3: watch.call(); await get_tree().process_frame
	_touch(2, opp - Vector2(160, 0), false); await _frames(2)
	expect.call("dash_back", "swipe back: dash back")
	# tap the gauge with full bars -> power
	for k in 90:
		if a.player.state == Fighter.S.IDLE:
			break
		await get_tree().physics_frame
	a.player.energy = 300.0
	var e0: float = a.player.energy
	var g: Vector2 = tc.gauge_rect().get_center()
	_touch(0, g, true)
	for k in 4: watch.call(); await get_tree().process_frame
	_touch(0, g, false); await _frames(3)
	var power_fired: bool = a.player.energy < e0 - 1.0 or a.player.state == Fighter.S.POWER
	print(("ok   " if power_fired else "FAIL ") + "tap the gauge: power fires (bars %d -> %d)" % [int(e0), int(a.player.energy)])
	ok = ok and power_fired
	print("GESTURES: ", "PASS" if ok else "FAIL")
	get_tree().quit()
