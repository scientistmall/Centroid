extends Node
## Headless smoke test. Run:
##   godot --headless --fixed-fps 60 --disable-vsync res://tests/smoke_test.tscn
## Exits with code 0 on success, 1 on failure.

var failures: Array = []
var stats := {"powers": 0, "hits": 0}


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		printerr("FAIL: ", msg)
	else:
		print("ok   ", msg)


func _ready() -> void:
	SceneRouter._busy = true   # keep the router from leaving this test scene
	StoryManager.new_game()
	await _test_story_files()
	await _test_story_player("prologue")
	await _test_story_player("ch01_pre")
	await _test_story_player("ch01_post")
	await _test_fight()
	print("\nRESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_story_files() -> void:
	var dir := DirAccess.open("res://data/story")
	for f in dir.get_files():
		if f.ends_with(".story"):
			var d := StoryParser.load_file("res://data/story/" + f)
			check(d["steps"].size() > 0, "%s parses (%d steps)" % [f, d["steps"].size()])
			var lines := 0
			for s in d["steps"]:
				if s["t"] == "line":
					lines += 1
					check(StoryParser.characters().has(s["who"]), "%s: speaker '%s' known" % [f, s["name"]]) if not StoryParser.characters().has(s["who"]) else null
			print("     %s: %d dialogue lines, next=%s" % [f, lines, d["next"]])


func _test_story_player(id: String) -> void:
	SceneRouter.current = {"type": "story", "id": id}
	var sp = load("res://scenes/story/story_player.tscn").instantiate()
	add_child(sp)
	await get_tree().process_frame
	var taps := 0
	while not sp._finished and taps < 2000:
		sp._card_elapsed = 99.0
		sp._blocked = false
		sp._on_tap()
		taps += 1
		await get_tree().process_frame
	check(sp._finished, "story '%s' plays to the end (%d taps)" % [id, taps])
	sp.queue_free()
	await get_tree().process_frame


func _test_fight() -> void:
	SceneRouter.current = {"type": "fight", "id": "fight01"}
	var arena = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame
	# AI controls both sides.
	arena.player.controller = AIController.new(0.7)
	arena.player.power_used.connect(func(_f, _n): stats["powers"] += 1)
	arena.enemy.power_used.connect(func(_f, _n): stats["powers"] += 1)
	arena.enemy.got_hit.connect(func(_f, _h): stats["hits"] += 1)
	arena.player.got_hit.connect(func(_f, _h): stats["hits"] += 1)
	var frames := 0
	while arena.phase != "over" and frames < 60 * 60 * 6:
		await get_tree().physics_frame
		frames += 1
		if arena.player.controller is PlayerController:   # relay/tag could swap it back
			arena.player.controller = AIController.new(0.7)
	check(arena.phase == "over", "fight01 finishes (%d frames, %.0f s game time)" % [frames, frames / 60.0])
	check(stats["hits"] > 5, "fighters land hits (%d)" % stats["hits"])
	check(stats["powers"] > 0, "powers are used (%d)" % stats["powers"])
	print("     wins: ", arena.hud.wins, "  player hp ", arena.player.hp, "  enemy hp ", arena.enemy.hp)
	var player_won: bool = arena.hud.wins[0] > arena.hud.wins[1]
	if player_won:
		arena._continue()
		check(StoryManager.has_flag("fight01_completed"), "victory sets fight01_completed")
	else:
		check(not StoryManager.has_flag("fight01_completed"), "defeat does not set the flag")
	var f := FileAccess.open(StoryManager.SAVE_PATH, FileAccess.READ)
	check(f != null and f.get_as_text().contains("prologue_seen"), "save file written with flags")
	arena.queue_free()
