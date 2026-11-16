extends Node
## Do fighters hold their summoned weapons properly? For each two-handed fighter and each power,
## while the weapon is out: how far each fist's centre is from the weapon's handle line (metres).
##   godot --headless --path . --fixed-fps 60 res://tests/grip_test.tscn [-- fight id]
const LIMIT := 0.07   # a fist wraps a handle: its centre is within a few cm of the handle's axis

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "fight01"
	SceneRouter._busy = true
	SceneRouter.current = {"type": "fight", "id": id, "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	a.cutins_enabled = false
	add_child(a)
	for i in 900:
		await get_tree().physics_frame
		if a.phase == "fight":
			break
	a.time_left = 999.0
	var mid: float = (a.stage.x + a.stage.y) / 2.0
	var fails := 0
	for f in [a.player, a.enemy]:
		f.controller = null
	for f in [a.player, a.enemy]:
		var m = a._puppets.get(f)
		if m == null or not m._two_handed:
			print("     ", f.char_id, ": not a two-handed weapon")
			continue
		for i in f.powers.size():
			a.player.position.x = mid - 210.0
			a.enemy.position.x = mid + 210.0
			for g in [a.player, a.enemy]:
				g.vel = Vector2.ZERO
				g.hp = g.max_hp
				g.hitstop = 0.0
				g.set_state(Fighter.S.IDLE)
				g.energy = Fighter.MAX_ENERGY
			for k in 50:
				await get_tree().physics_frame
				await get_tree().process_frame
			f._try_power(i)
			var worst := [0.0, 0.0]
			var sum := [0.0, 0.0]
			var n := 0
			var first_two := -1.0
			var t := 0.0
			while f.state == Fighter.S.POWER and t < 3.0:
				await get_tree().physics_frame
				await get_tree().process_frame
				t += 1.0 / 60.0
				if m._wshow < 0.6:
					continue
				var wx: Transform3D = m._weapon.transform
				var ax: Vector3 = wx.basis.y.normalized()
				var k2 := 0
				for side in ["Right", "Left"]:
					var p: Vector3 = m._fist(side) - wx.origin
					var d := (p - ax * p.dot(ax)).length()
					worst[k2] = maxf(worst[k2], d)
					sum[k2] += d
					k2 += 1
				n += 1
				if first_two < 0.0 and m._two_w > 0.9:
					first_two = t
			var ok: bool = n > 0 and worst[0] <= LIMIT and worst[1] <= LIMIT
			if not ok:
				fails += 1
			print("%s %s %s: fists off the handle, right %.3f / left %.3f m at worst (mean %.3f / %.3f), both hands on from %.2f s" % [
				"ok  " if ok else "FAIL", f.char_id, f.powers[i].get("name", "?"), worst[0], worst[1],
				sum[0] / maxf(n, 1), sum[1] / maxf(n, 1), first_two])
			for k in 90:
				await get_tree().physics_frame
				await get_tree().process_frame
	print("GRIP: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(1 if fails else 0)
