extends Node
## Fires every fighter's third power (the unblockable ultimate) and saves a frame of each.
##   godot --path . --rendering-method gl_compatibility --resolution 1600x720 res://tests/ult_gallery.tscn -- <out_dir>
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var only: Array = OS.get_cmdline_user_args().slice(1)
	for fid in ["fight01", "fight02", "fight03", "fight04"]:
		if not only.is_empty() and not only.has(fid):
			continue
		for side in [0, 1]:
			SceneRouter.current = {"type": "fight", "id": fid, "no_briefing": true}
			var a = load("res://scenes/fight/arena.tscn").instantiate()
			add_child(a)
			for i in 600:
				await get_tree().physics_frame
				if a.phase == "fight":
					break
			a.player.controller = null
			a.enemy.controller = null
			for f in [a.player, a.enemy]:
				f.advance = false
			a.player.position.x = a._cam_x - 200.0
			a.enemy.position.x = a._cam_x + 200.0
			for i in 20:
				await get_tree().physics_frame
			var f: Fighter = a.player if side == 0 else a.enemy
			f.energy = 300.0
			f._try_power(2)
			var su := float(f.power_def.get("startup", 0.3))
			var t := 0.0
			var extra := float(OS.get_environment("ULT_DT")) if OS.get_environment("ULT_DT") != "" else 0.12
			while t < su + extra:
				await get_tree().physics_frame
				t += get_physics_process_delta_time()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/ult_%s.png" % [out, f.char_id])
			print("saved ", f.char_id)
			a.queue_free()
			await get_tree().process_frame
	get_tree().quit()
