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
	get_tree().quit()
