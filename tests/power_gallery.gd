extends Node
## Visual check of every power's 3D effect. For each fight, each fighter uses each power at a
## comfortable distance and a frame is saved at the effect's peak.
##   xvfb-run godot --rendering-method gl_compatibility --resolution 2400x1080 \
##     res://tests/power_gallery.tscn -- <out_dir> [fight01 ...]

const DELAYS := {"projectile": 0.3, "burst": 0.12, "dash": 0.12, "buff": 0.15, "wall": 0.25,
				 "pull": 0.35, "lash": 0.06, "drain": 0.1, "summon": 0.3}

var out := "user://powers"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var fights: Array = args.slice(1) if args.size() > 1 else ["fight01", "fight02", "fight03", "fight04"]
	DirAccess.make_dir_recursive_absolute(out)
	SceneRouter._busy = true
	StoryManager.new_game()
	for id in fights:
		await _fight(id)
	get_tree().quit()


func _fight(id: String) -> void:
	SceneRouter.current = {"type": "fight", "id": id, "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	await get_tree().process_frame
	var t := 0
	while a.phase != "fight" and t < 600:
		await get_tree().physics_frame
		t += 1
	a.cutins_enabled = false
	for f in [a.player, a.enemy]:
		f.controller = null
	for f in [a.player, a.enemy]:
		for i in f.powers.size():
			# stand apart, both idle, full energy
			a.player.position.x = 760.0
			a.enemy.position.x = 1240.0
			for g in [a.player, a.enemy]:
				g.vel = Vector2.ZERO
				g.statuses.clear()
				g.set_state(Fighter.S.IDLE)
				g.energy = Fighter.MAX_ENERGY
			for k in 20:
				await get_tree().physics_frame
			var pd: Dictionary = f.powers[i]
			f._try_power(i)
			var wait: float = float(pd.get("startup", 0.2)) + float(DELAYS.get(pd.get("type", ""), 0.2))
			for k in int(wait * 60.0):
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			var name := "%s_%s_%d" % [id, f.char_id, i + 1]
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
			print("saved ", name, " (", pd.get("name", ""), ")")
			for k in 70:
				await get_tree().physics_frame
	a.queue_free()
	await get_tree().process_frame
