extends Node
## Black 3D on a phone GPU: the fight must step its graphics down HIGH -> LOW -> SAFE (restarting
## the fight each time, remembering the level), then explain on screen if even SAFE is black.
##   godot --headless --path . res://tests/gfx_fallback_test.tscn

var _last: Node


func _ready() -> void:
	# outlive the scene changes: stop being the current scene (the router replaces that)
	var tree := get_tree()
	await tree.process_frame
	tree.current_scene = null
	Settings.graphics = Settings.Gfx.AUTO
	Settings.graphics_detected = 0
	var arena_script = load("res://scripts/fight/arena.gd")
	arena_script.force_black_check = true
	var seen: Array = []
	SceneRouter.go({"type": "fight", "id": "fight01", "no_briefing": true}, 0.05)
	var t0 := Time.get_ticks_msec()
	var note_shown := false
	while Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
		var a = get_tree().current_scene
		if a and a.get("stage3d") != null and a != _last:
			_last = a
			seen.append(a.stage3d.level)
		if a and a.get("stage3d") != null and a.stage3d and a.stage3d.level == Settings.Gfx.SAFE and a.ui_layer:
			for c in a.ui_layer.get_children():
				if c is Label and String(c.text).begins_with("3D could not"):
					note_shown = true
		if note_shown:
			break
	var ok: bool = seen == [Settings.Gfx.HIGH, Settings.Gfx.LOW, Settings.Gfx.SAFE] and note_shown \
		and Settings.graphics_detected == Settings.Gfx.SAFE
	print("levels tried: ", seen, "  remembered: ", Settings.graphics_detected, "  note shown: ", note_shown)
	print("GFX FALLBACK: ", "PASS" if ok else "FAIL")
	Settings.graphics_detected = 0
	Settings.save_settings()
	get_tree().quit(0 if ok else 1)
