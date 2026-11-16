extends Node
## Both fighters standing in their idle guard at fighting range, AI off: faces, heads, sizes.
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	SceneRouter.current = {"type": "fight", "id": "fight01", "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	for i in 600:
		await get_tree().physics_frame
		if a.phase == "fight":
			break
	a.player.controller = null
	a.enemy.controller = null
	for i in 90:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	# close-ups of the enemy's face: head turned toward the opponent (as in the fight), then
	# square to the camera
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] in ["close", "close_player"]:
		var m = a._puppets[a.player if args[1] == "close_player" else a.enemy]
		a.set_process(false)   # the fight camera stops following
		var cam: Camera3D = a.stage3d.camera
		for k in 2:
			if k == 1:
				m.set_physics_process(false)
				m.set_process(false)
				m.rotation.y = 0.0
			for i in 6:
				await get_tree().process_frame
			var sk: Skeleton3D = m._sk
			var hb := sk.find_bone("Head")
			var hp: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
			cam.global_position = hp + Vector3(0, 0.08, 0.75)
			cam.look_at(hp + Vector3(0, 0.05, 0))
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.replace(".png", "_close%d.png" % k))
	get_tree().quit()
