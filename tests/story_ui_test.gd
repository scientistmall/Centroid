extends Node
## Story reader on a phone: speech text stays sharp when the page camera zooms, earlier panels'
## text never fades, the log has a way back, and the back button never leaves the game.
##   godot --path . --resolution 2400x1080 res://tests/story_ui_test.tscn -- <out_dir>
## (headless works too; it then only checks the behaviour, not the pictures)

var out := ""
var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _save(name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	SceneRouter._busy = true
	StoryManager.new_game()
	SceneRouter.current = {"type": "story", "id": "prologue"}
	var sp = load("res://scenes/story/story_player.tscn").instantiate()
	add_child(sp)
	await get_tree().process_frame
	# read on until a page has several panels with text in them
	var tries := 0
	while tries < 120:
		tries += 1
		sp._card_elapsed = 99.0
		while sp._blocked:
			await get_tree().process_frame
		sp._on_tap()
		for i in 3: await get_tree().process_frame
		var with_text := 0
		for pv in sp._panels.values():
			if pv._items.any(func(it): return it.has_method("done")):
				with_text += 1
		if with_text >= 2:
			break
	if not sp._waiting_card:
		sp._on_tap()
	for i in 40: await get_tree().process_frame
	await _save("story_zoomed")
	# every bubble on the page fully opaque, drawn with the distance-field font
	var faded := 0
	var plain := 0
	for pv in sp._panels.values():
		for it in pv._items:
			if it.has_method("done"):
				if it.modulate.a < 0.99:
					faded += 1
				if not (it._font is FontFile and (it._font as FontFile).multichannel_signed_distance_field):
					plain += 1
	_check(faded == 0, "no faded speech text on the page (%d faded)" % faded)
	_check(plain == 0, "speech text uses the sharp (MSDF) font (%d plain)" % plain)
	# whole-page view
	sp._focus(Rect2(Vector2.ZERO, sp._page.size), 0.01)
	for i in 30: await get_tree().process_frame
	await _save("story_page")
	# log: open, it has a back button, the phone's back button closes it
	sp._open_log()
	for i in 10: await get_tree().process_frame
	await _save("story_log")
	var has_back := false
	for b in sp._log_view.find_children("*", "Button", true, false):
		if "BACK" in b.text:
			has_back = true
	_check(has_back, "log has a BACK TO STORY button")
	SceneRouter._busy = false
	SceneRouter.back()
	await get_tree().process_frame
	_check(sp._log_view == null, "back button closes the log")
	SceneRouter.back()
	await get_tree().process_frame
	_check(sp._menu_view != null, "back button opens the story menu (does not quit)")
	await _save("story_menu")
	SceneRouter.back()
	await get_tree().process_frame
	_check(sp._menu_view == null, "back button closes the story menu")
	print("STORY UI: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(1 if fails else 0)
