extends Node
## Does the fight LOOK controlled? Checks the 3D bodies against the fight logic (fight01):
##   a light attack shows within a few frames of the press; a full five-hit combo connects
##   every hit with the bodies never overlapping; both fighters freeze together on each hit;
##   every hit restarts the reaction with a crossfade (a new clip name, no snap); heavy blows
##   get the heavy reaction; the AI's blocks are not accidental parries at Normal; every attack
##   clip's strike frame is in its first 60%; no wind-up plays faster than about 2x.
##   godot --headless --path . --fixed-fps 60 res://tests/feel_test.tscn

var a
var fails := 0


class Script_ extends RefCounted:
	var hold := {}
	var once := {}

	func get_input(_f, _d) -> Dictionary:
		var out := hold.duplicate()
		for k in once:
			out[k] = true
		once.clear()
		return out


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _reset(gap: float) -> Array:
	for n in a.effects.get_children():
		n.queue_free()
	var mid: float = (a.stage.x + a.stage.y) / 2.0
	var ps := Script_.new()
	var es := Script_.new()
	for f in [a.player, a.enemy]:
		f.hp = f.max_hp
		f.vel = Vector2.ZERO
		f.stun_time = 0.0
		f.hitstop = 0.0
		f.invuln = 0.0
		f.advance = false
		f._buf.clear()
		f.set_state(Fighter.S.IDLE)
		if "string_lock" in f:
			f.string_lock = 0.0
	a.player.position = Vector2(mid - gap / 2.0, a.ground_y)
	a.enemy.position = Vector2(mid + gap / 2.0, a.ground_y)
	a.player.controller = ps
	a.enemy.controller = es
	await _frames(3)
	return [ps, es]


func _ready() -> void:
	Settings.difficulty = 1
	StoryManager.losses = {}
	SceneRouter._busy = true
	SceneRouter.current = {"type": "fight", "id": "fight01", "no_briefing": true}
	a = load("res://scenes/fight/arena.tscn").instantiate()
	a.cutins_enabled = false
	add_child(a)
	for i in 900:
		await get_tree().physics_frame
		if a.phase == "fight":
			break
	a.time_left = 999.0
	var pm = a._puppets[a.player]
	var em = a._puppets[a.enemy]
	_test_clips(pm)
	# 1. a light shows at once
	var c := await _reset(200.0)
	c[0].once["light"] = true
	var n := 0
	while n < 10 and not String(pm._clip).begins_with("light_1"):
		await get_tree().process_frame
		n += 1
	_check(n <= 3, "a light attack is on screen %d frames after the press" % n)
	await _frames(40)
	# 2-5. a full combo: every hit lands, no overlap, both freeze, each reaction crossfades
	c = await _reset(200.0)
	var hits := 0
	var min_gap := 9999.0
	var both_froze := 0
	var held_pose := 0
	var clips := []
	var heavy_ok := true
	var last_hp: float = a.enemy.hp
	for i in 150:
		if i % 9 == 0 and i < 80:
			c[0].once["light"] = true
		await get_tree().physics_frame
		min_gap = minf(min_gap, a.enemy.position.x - a.player.position.x)
		if a.enemy.hp < last_hp:
			hits += 1
			last_hp = a.enemy.hp
			if a.player.hitstop > 0.0 and a.enemy.hitstop > 0.0:
				both_froze += 1
			await get_tree().process_frame
			var pos0: float = em._ap.current_animation_position
			await get_tree().process_frame
			if a.enemy.hitstop > 0.0 and is_equal_approx(pos0, em._ap.current_animation_position):
				held_pose += 1
			clips.append(String(em._clip))
			var want_heavy: bool = a.player.move_kind == "medium" and a.player.chain_index == 1
			if bool(a.enemy.get_meta("hurt_heavy", false)) != want_heavy:
				heavy_ok = false
	_check(hits == 5, "a five-hit combo (L-L-L-L-M) lands every hit (%d)" % hits)
	_check(min_gap >= Fighter.MIN_GAP - 1.0, "the bodies never overlap during the combo (closest %d px)" % int(min_gap))
	_check(both_froze == hits and hits > 0, "both fighters freeze on every hit (%d of %d)" % [both_froze, hits])
	_check(held_pose >= hits - 1 and hits > 0, "the hit body holds its pose during hit-stop (%d of %d)" % [held_pose, hits])
	var fresh := true
	for k in range(1, clips.size()):
		if clips[k] == clips[k - 1]:
			fresh = false
	_check(fresh and clips.size() == hits, "every hit crossfades into a fresh reaction %s" % str(clips))
	_check(heavy_ok, "the combo ender gets the heavy reaction, the rest the light one")
	await _frames(60)
	# nobody sinks: through hit reactions (both clips), a knockdown and the get-up, the bodies
	# stay on the floor without needing the safety lift
	c = await _reset(200.0)
	var worst := 0.0
	var lowest := 9.0
	for i in 200:
		if i % 9 == 0 and i < 80:
			c[0].once["light"] = true
		if i == 100:
			a.player.energy = 300.0
			a.player._try_power(1)   # knocks the enemy down
		await get_tree().physics_frame
		await get_tree().process_frame
		for m in [pm, em]:
			worst = maxf(worst, m.floor_lift)
			lowest = minf(lowest, m.lowest_point())
	var went_down := false
	for i in 120:
		await get_tree().physics_frame
		await get_tree().process_frame
		went_down = went_down or a.enemy.state == Fighter.S.DOWN
		for m in [pm, em]:
			worst = maxf(worst, m.floor_lift)
			lowest = minf(lowest, m.lowest_point())
	_check(went_down, "the second power knocks the opponent down (then they get up)")
	_check(worst < 0.03, "no clip puts a fighter under the floor (largest lift needed %.3f m, lowest point %.3f m)" % [worst, lowest])
	# 6. the AI's blocks against mediums are not accidental parries at Normal
	c = await _reset(240.0)
	a.enemy.controller = AIController.new(Settings.enemy_level(0.5, 0))
	var parries := [0]
	var on_parry := func(_d, _att): parries[0] += 1
	a.enemy.parried.connect(on_parry)
	for i in 15:
		a.player.position.x = a.enemy.position.x - 240.0
		c[0].once["forward"] = true
		await _frames(50)
	a.enemy.parried.disconnect(on_parry)
	_check(parries[0] == 0, "the AI (Normal) blocks mediums without accidental parries (%d parries)" % parries[0])
	print("FEEL: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(1 if fails else 0)


## 7-8. strike frames early enough; wind-ups no faster than about 2x
func _test_clips(m) -> void:
	var late := []
	var fast := []
	var f: Fighter = m.fighter
	for kind in ["light", "medium", "heavy"]:
		for i in Fighter.MOVE_TABLE[kind].size():
			var mv: Dictionary = f._make_move(kind, i)
			var clip := "light_%d" % (i + 1) if kind == "light" else ("heavy_%d" % (i + 1) if kind == "medium" else "heavy_1")
			var an: Animation = m._anims.get_animation(clip)
			var s: float = an.get_meta("strike", 0.0)
			if s > an.length * 0.6 + 0.01:
				late.append(clip)
			var su: float = mv["startup"]
			var speed: float = (m._timeline(clip, su, su, mv["active"], mv["recovery"]) - m._timeline(clip, 0.0, su, mv["active"], mv["recovery"])) / su
			if speed > 2.1:
				fast.append("%s x%.1f" % [clip, speed])
	# every clip's hips are in the set's units: standing clips keep the hips near idle height
	var lib: AnimationLibrary = m._anims
	var idle_h := _hips_range(lib.get_animation("idle"))
	var off := []
	for n in lib.get_animation_list():
		if String(n).ends_with("~") or n in ["knockdown", "get_up", "defeat"]:
			continue
		var r := _hips_range(lib.get_animation(n))
		if r.y > 0.0 and (r.y < idle_h.y * 0.45 or r.y > idle_h.y * 1.8):
			off.append("%s (hips up to %.2f, idle %.2f)" % [n, r.y, idle_h.y])
	var gu := _hips_range(lib.get_animation("get_up"))
	if gu.y < idle_h.y * 0.6:
		off.append("get_up never stands (hips up to %.2f, idle %.2f)" % [gu.y, idle_h.y])
	_check(off.is_empty(), "every clip is in the set's units %s" % str(off))
	_check(late.is_empty(), "every attack clip strikes in its first 60%% %s" % str(late))
	_check(fast.is_empty(), "no wind-up plays faster than 2x %s" % str(fast))


## [lowest, highest] hips height in a clip (its own units); (0, 0) if it has no hips track.
func _hips_range(an: Animation) -> Vector2:
	for t in an.get_track_count():
		if an.track_get_type(t) == Animation.TYPE_POSITION_3D and String(an.track_get_path(t)).ends_with("Hips"):
			var lo := INF
			var hi := -INF
			for k in an.track_get_key_count(t):
				var y: float = (an.track_get_key_value(t, k) as Vector3).y
				lo = minf(lo, y)
				hi = maxf(hi, y)
			return Vector2(lo, hi)
	return Vector2.ZERO
