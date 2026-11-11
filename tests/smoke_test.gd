extends Node
## Headless smoke test. Run:
##   godot --headless --fixed-fps 60 --disable-vsync res://tests/smoke_test.tscn
## Exits with code 0 on success, 1 on failure.

var failures: Array = []
var stats := {"powers": 0, "hits": 0}
var fights_done := 0


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
	await _test_story_player("ch02_pre")
	await _test_story_player("ch02_post")
	await _test_fight("fight01", [])
	await _test_fight("fight02", ["Veil of Mist", "Mirror Double", "Clear Sight"])
	check(fights_done == 2, "all fight tests completed (%d/2)" % fights_done)
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


func _test_fight(id: String, must_use: Array) -> void:
	stats = {"powers": 0, "hits": 0, "used": {}, "max_clones": 0}
	SceneRouter.current = {"type": "fight", "id": id}
	var arena = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame
	# AI controls both sides.
	arena.player.controller = AIController.new(0.7)
	for f in [arena.player, arena.enemy]:
		f.power_used.connect(func(_f, n):
			stats["powers"] += 1
			stats["used"][n] = true)
		f.got_hit.connect(func(_f, _h): stats["hits"] += 1)
	var frames := 0
	while arena.phase != "over" and frames < 60 * 60 * 6:
		await get_tree().physics_frame
		frames += 1
		stats["max_clones"] = maxi(stats["max_clones"], get_tree().get_nodes_in_group("clones").size())
		if arena.player.controller is PlayerController:   # relay/tag could swap it back
			arena.player.controller = AIController.new(0.7)
	check(arena.phase == "over", "%s finishes (%d frames, %.0f s game time)" % [id, frames, frames / 60.0])
	check(stats["hits"] > 5, "%s: fighters land hits (%d)" % [id, stats["hits"]])
	check(stats["powers"] > 0, "%s: powers are used (%d) %s" % [id, stats["powers"], stats["used"].keys()])
	for n in must_use:
		check(stats["used"].has(n), "%s: '%s' was used" % [id, n])
	if must_use.has("Mirror Double"):
		check(stats["max_clones"] > 0, "%s: a clone appeared" % id)
	print("     wins: ", arena.hud.wins, "  player hp ", arena.player.hp, "  enemy hp ", arena.enemy.hp)
	var flag: String = arena.fight.get("flag", "")
	var player_won: bool = arena.hud.wins[0] > arena.hud.wins[1]
	if player_won:
		arena._continue()
		check(StoryManager.has_flag(flag), "victory sets %s" % flag)
	else:
		check(not StoryManager.has_flag(flag), "defeat does not set %s" % flag)
	var f := FileAccess.open(StoryManager.SAVE_PATH, FileAccess.READ)
	check(f != null and f.get_as_text().contains("prologue_seen"), "save file written with flags")
	fights_done += 1
	arena.queue_free()
	await get_tree().process_frame
