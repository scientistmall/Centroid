extends Node
## How fighters hold their summoned weapons: for each fighter of a fight and each power, frames
## through the wind-up, the strike and the recovery.
##   godot --rendering-method gl_compatibility --resolution 1600x900 \
##     res://tests/weapon_hold_shot.tscn -- <out_dir> [fight id]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var id: String = args[1] if args.size() > 1 else "fight01"
	DirAccess.make_dir_recursive_absolute(out)
	SceneRouter._busy = true
	SceneRouter.current = {"type": "fight", "id": id, "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	for i in 900:
		await get_tree().physics_frame
		if a.phase == "fight":
			break
	a.cutins_enabled = false
	a.time_left = 999.0
	var mid: float = (a.stage.x + a.stage.y) / 2.0
	for f in [a.player, a.enemy]:
		f.controller = null
	for f in [a.player, a.enemy]:
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
			var pd: Dictionary = f.powers[i]
			var su: float = pd.get("startup", 0.2)
			var total: float = su + float(pd.get("active", 0.1)) + float(pd.get("recovery", 0.3))
			f._try_power(i)
			var marks := [su * 0.35, su * 0.8, su + 0.04, su + 0.16, total * 0.85]
			var n := 0
			var t := 0.0
			while n < marks.size() and t < total + 0.5:
				await get_tree().physics_frame
				t += 1.0 / 60.0
				if t >= marks[n]:
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("%s/%s_p%d_%d.png" % [out, f.char_id, i + 1, n])
					n += 1
			for k in 120:
				await get_tree().physics_frame
	get_tree().quit()
