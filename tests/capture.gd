extends Node
## Saves screenshots of key screens. Run under Xvfb with a real renderer:
##   xvfb-run -s "-screen 0 2400x1080x24" godot --rendering-method gl_compatibility \
##     --resolution 2400x1080 res://tests/capture.tscn -- <out_dir>

var out := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	SceneRouter._busy = true
	StoryManager.new_game()
	await _shot_menu()
	await _shot_story("prologue", 6, "story_opening")
	await _shot_story("prologue", 60, "story_flashback")
	await _shot_story("prologue", 1, "story_card")
	await _shot_story("ch02_pre", 3, "forest_story")
	await _shot_fight("fight01", "fight")
	await _shot_fight("fight02", "mist")
	await _shot_story("ch03_pre", 4, "pass_story")
	await _shot_fight("fight03", "pass")
	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _shot_menu() -> void:
	var m = load("res://scenes/main_menu.tscn").instantiate()
	add_child(m)
	for i in 10: await get_tree().process_frame
	await _save("menu")
	m.queue_free()


func _shot_story(id: String, taps: int, name: String) -> void:
	SceneRouter.current = {"type": "story", "id": id}
	var sp = load("res://scenes/story/story_player.tscn").instantiate()
	add_child(sp)
	await get_tree().process_frame
	for i in taps:
		sp._card_elapsed = 99.0
		sp._blocked = false
		sp._on_tap()
		await get_tree().process_frame
	if not sp._waiting_card:
		sp._on_tap()  # finish typing
	for i in 40: await get_tree().process_frame
	await _save(name)
	sp.queue_free()


func _shot_fight(id: String, prefix: String) -> void:
	SceneRouter.current = {"type": "fight", "id": id}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	await get_tree().process_frame
	a.player.controller = AIController.new(0.8)
	var t := 0
	while a.phase != "fight" and t < 600:
		await get_tree().physics_frame
		t += 1
	var shots := 0
	t = 0
	while shots < 3 and t < 3000:
		await get_tree().physics_frame
		t += 1
		var interesting: bool = a.player.state in [Fighter.S.ATTACK, Fighter.S.POWER] or a.enemy.state == Fighter.S.POWER
		if id == "fight02":
			interesting = get_tree().get_nodes_in_group("clones").size() > 0 or a.enemy.has_status("veil") or a.player.has_status("clear_sight")
		if id == "fight03":
			var has_wall := false
			for n in a.effects.get_children():
				if n is StoneWall:
					has_wall = true
			interesting = has_wall or a.player.has_status("gravity") or get_tree().get_nodes_in_group("projectiles").size() > 1
		if interesting and t > 120 * (shots + 1):
			await _save("%s_%d" % [prefix, shots])
			shots += 1
	a.queue_free()
