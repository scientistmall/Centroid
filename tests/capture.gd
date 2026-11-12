extends Node
## Saves screenshots of key screens. Run under Xvfb with a real renderer:
##   xvfb-run -s "-screen 0 2400x1080x24" godot --rendering-method gl_compatibility \
##     --resolution 2400x1080 res://tests/capture.tscn -- <out_dir> [only...]
## Optional extra args limit which shots run (e.g. "menu fight story_opening").

var out := "user://shots"
var only: Array = []


func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	only = args.slice(1)
	DirAccess.make_dir_recursive_absolute(out)
	SceneRouter._busy = true
	StoryManager.new_game()
	if _want("menu"): await _shot_menu()
	if _want("story_opening"): await _shot_story("prologue", 11, "story_opening")
	if _want("story_flashback"): await _shot_story("prologue", 60, "story_flashback")
	if _want("story_card"): await _shot_story("prologue", 1, "story_card")
	if _want("forest_story"): await _shot_story("ch02_pre", 3, "forest_story")
	if _want("fight"): await _shot_fight("fight01", "fight")
	if _want("mist"): await _shot_fight("fight02", "mist")
	if _want("pass_story"): await _shot_story("ch03_pre", 4, "pass_story")
	if _want("pass"): await _shot_fight("fight03", "pass")
	if _want("sanctuary_story"): await _shot_story("ch04_pre", 5, "sanctuary_story")
	if _want("sanctuary"): await _shot_fight("fight04", "sanctuary")
	if _want("cutin"): await _shot_cutin()
	if _want("chapters"): await _shot_scene("res://scenes/ui/chapter_select.tscn", "chapters", true)
	if _want("settings"): await _shot_settings()
	if _want("briefing"): await _shot_briefing("fight01", "briefing")
	if _want("briefing4"): await _shot_briefing("fight04", "briefing4")
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
	SceneRouter.current = {"type": "fight", "id": id, "no_briefing": true}
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
		if id == "fight04":
			var has_lash := false
			for n in a.effects.get_children():
				if n is LashFx:
					has_lash = true
			interesting = has_lash or a.player.has_status("poison") or a.player.has_status("purified") or a.player.has_status("cursed")
		if interesting and t > 120 * (shots + 1):
			await _save("%s_%d" % [prefix, shots])
			shots += 1
	a.queue_free()


func _shot_cutin() -> void:
	SceneRouter.current = {"type": "fight", "id": "fight01", "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	var t := 0
	while a.phase != "fight" and t < 600:
		await get_tree().physics_frame
		t += 1
	a.player.controller = null
	a.enemy.controller = null
	a.player.energy = 100.0
	a.player._try_power(0)
	for i in 12:
		await get_tree().process_frame
	await _save("cutin_player")
	await get_tree().create_timer(1.5, true, false, true).timeout
	a.enemy.energy = 100.0
	a.enemy._try_power(1)
	for i in 14:
		await get_tree().process_frame
	await _save("cutin_enemy")
	a.queue_free()


func _shot_scene(path: String, name: String, with_progress := false) -> void:
	if with_progress:
		for f in ["prologue_seen", "fight01_completed", "fight02_completed"]:
			StoryManager.flags[f] = true
	var sc = load(path).instantiate()
	add_child(sc)
	for i in 20: await get_tree().process_frame
	await _save(name)
	sc.queue_free()
	StoryManager.new_game()


func _shot_settings() -> void:
	var m = load("res://scenes/main_menu.tscn").instantiate()
	add_child(m)
	m.add_child(SettingsPanel.new())
	for i in 10: await get_tree().process_frame
	await _save("settings")
	m.queue_free()


func _shot_briefing(id: String, name: String) -> void:
	SceneRouter.current = {"type": "fight", "id": id}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	await get_tree().create_timer(1.3).timeout
	await _save(name)
	a.queue_free()
