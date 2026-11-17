extends Node
## Round 2 doesn't start at once: after round 1's K.O. there is a 3-2-1 countdown, during which
## the clock is frozen and nobody can act; then FIGHT! and the round is live.
##   godot --headless --path . --fixed-fps 60 res://tests/round_test.tscn

func _ready() -> void:
	SceneRouter._busy = true
	StoryManager.losses = {}
	SceneRouter.current = {"type": "fight", "id": "fight01", "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	a.cutins_enabled = false
	add_child(a)
	for i in 900:
		await get_tree().physics_frame
		if a.phase == "fight":
			break
	var ok := true
	# end round 1: the enemy falls
	a.player.controller = null
	a.enemy.controller = null
	a.enemy.hp = 1.0
	a.enemy.receive_hit(a.player, {"damage": 50.0, "stun": 0.3, "knock": 100.0})
	var t0 := Time.get_ticks_msec()
	while a.round_no < 2 and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	# round 2 is set up: now the countdown
	var frames := 0
	var clock: float = a.time_left
	var frozen_clock := true
	var acted := ""
	while a.phase != "fight" and frames < 60 * 15:
		await get_tree().physics_frame
		frames += 1
		frozen_clock = frozen_clock and is_equal_approx(a.time_left, clock)
		if acted == "" and a.phase != "fight" and (a.player.state != Fighter.S.FROZEN or a.enemy.state != Fighter.S.FROZEN):
			acted = "states %d / %d at %.2f s" % [a.player.state, a.enemy.state, frames / 60.0]
	var waited := frames / 60.0   # game time (fixed 60 fps)
	var shown: Array = a.countdown_shown
	print(("ok   " if a.round_no == 2 else "FAIL ") + "round 1 ends and round 2 is set up")
	print(("ok   " if shown == [3, 2, 1] else "FAIL ") + "countdown 3, 2, 1 before round 2 %s" % str(shown))
	print(("ok   " if waited >= 3.5 else "FAIL ") + "round 2 goes live only after the countdown (%.1f s)" % waited)
	print(("ok   " if frozen_clock and acted == "" else "FAIL ") + "during the countdown the clock waits and nobody can act %s" % acted)
	print(("ok   " if a.phase == "fight" else "FAIL ") + "round 2 starts (FIGHT!)")
	ok = a.round_no == 2 and shown == [3, 2, 1] and waited >= 3.5 and frozen_clock and acted == "" and a.phase == "fight"
	print("ROUNDS: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
