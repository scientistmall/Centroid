extends Node
## Records a few seconds of a fight for checking the live arenas (no input; the AI fights).
##   godot --rendering-method gl_compatibility --resolution 1200x540 --write-movie out.avi \
##     --fixed-fps 30 res://tests/arena_movie.tscn -- fight01 6

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "fight01"
	var secs := float(args[1]) if args.size() > 1 else 6.0
	SceneRouter._busy = true
	StoryManager.new_game()
	SceneRouter.current = {"type": "fight", "id": id, "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	await get_tree().create_timer(secs).timeout
	get_tree().quit()
