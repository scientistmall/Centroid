extends Node
## Balance: runs full AI-vs-AI matches and reports who wins and by how much.
##   godot --headless --path . --fixed-fps 60 --disable-vsync res://tests/balance_test.tscn -- \
##       <fight id> <player level> <enemy level or "fight"> <matches> [difficulty 0..2] [losses] [min wins]
## "fight" uses the enemy level the game would use for that fight (fight json + difficulty +
## progression). The player side stands in for a human of the given skill.

var results: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var fid: String = args[0] if args.size() > 0 else "fight01"
	var lp := float(args[1]) if args.size() > 1 else 0.5
	var le_s: String = args[2] if args.size() > 2 else "fight"
	var n := int(args[3]) if args.size() > 3 else 4
	if args.size() > 4:
		Settings.difficulty = int(args[4])
	var losses := int(args[5]) if args.size() > 5 else 0   # earlier defeats at this fight (easing)
	SceneRouter._busy = true
	var wins := 0
	var margin := 0.0
	for m in n:
		SceneRouter.current = {"type": "fight", "id": fid, "no_briefing": true}
		StoryManager.losses = {fid: losses}
		var a = load("res://scenes/fight/arena.tscn").instantiate()
		a.cutins_enabled = false
		add_child(a)
		await get_tree().physics_frame
		a.player.controller = AIController.new(lp)
		if le_s != "fight":
			a.enemy.controller = AIController.new(float(le_s))
		var level: float = a.enemy.controller.level
		var t := 0
		while a.phase != "over" and t < 60 * 400:
			await get_tree().physics_frame
			t += 1
		var won: bool = a.hud.wins[0] > a.hud.wins[1]
		if won:
			wins += 1
		margin += (a.player.hp - a.enemy.hp) / 1000.0
		print("match %d: %s  wins %s  hp %d / %d  (enemy level %.2f, %d s)" % [m + 1, "PLAYER" if won else "ENEMY",
			str(a.hud.wins), int(a.player.hp), int(a.enemy.hp), level, t / 60])
		a.queue_free()
		get_tree().paused = false
		await get_tree().process_frame
	StoryManager.losses = {}   # leave no recorded defeats behind
	StoryManager.save_game()
	var need := int(args[6]) if args.size() > 6 else 0   # optional: fail below this many wins
	if wins < need:
		print("FAIL: fewer than %d wins" % need)
	print("BALANCE %s player %.2f vs enemy %s (difficulty %d, losses %d): player won %d / %d (avg hp margin %+.2f)" % [fid, lp, le_s, Settings.difficulty, losses, wins, n, margin / n])
	get_tree().quit(1 if wins < need else 0)
