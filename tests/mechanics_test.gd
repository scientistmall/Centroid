extends Node
## MCOC mechanics, checked in a real fight01 arena (Kael vs Rhex):
##   block stops basic attacks (0 damage), specials chip 10%, the ultimate goes through block;
##   parry stuns the attacker; the start of a dash back evades; the fighters never cross;
##   every power of both fighters lands on a non-blocking target in range; a power tapped mid-
##   combo fires at once (buffer); same strikes deal the same damage (difficulty scales it);
##   the stage is wide.
##   godot --headless --path . --fixed-fps 60 res://tests/mechanics_test.tscn

var a
var fails := 0


class Script_ extends RefCounted:
	var hold := {}      # action -> true while held
	var once := {}      # action -> pressed for one tick

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


## Fresh state: both idle at `gap` apart in mid-stage, full HP, given energy, scripted controls.
func _reset(gap: float, e_player := 0.0, e_enemy := 0.0) -> Array:
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
		f.clear_statuses()
		f.set_state(Fighter.S.IDLE)
	a.player.position = Vector2(mid - gap / 2.0, a.ground_y)
	a.enemy.position = Vector2(mid + gap / 2.0, a.ground_y)
	a.player.energy = e_player
	a.enemy.energy = e_enemy
	a.player.controller = ps
	a.enemy.controller = es
	await _frames(2)
	return [ps, es]


func _ready() -> void:
	Settings.difficulty = 1
	StoryManager.losses = {}   # no easing from earlier defeats
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
	await _test_block()
	await _test_parry()
	await _test_evade()
	await _test_powers_land()
	await _test_buffer()
	await _test_no_cross()
	_test_equal_damage()
	_check(is_equal_approx(a.stage.y - a.stage.x, 2300.0), "stage is 2300 px wide (%d)" % int(a.stage.y - a.stage.x))
	print("MECHANICS: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(1 if fails else 0)


func _test_block() -> void:
	var c := await _reset(170.0)
	c[0].hold["block"] = true
	await _frames(20)   # guard well before the strikes (no parry)
	for i in 10:
		c[1].once["light"] = true
		await _frames(9)
	await _frames(30)
	_check(a.player.hp == a.player.max_hp, "holding block takes no damage from basic attacks (hp %d)" % int(a.player.hp))
	# a blocked special chips 10%
	c = await _reset(420.0, 0.0, 100.0)
	c[0].hold["block"] = true
	await _frames(20)
	c[1].once["power_1"] = true
	await _frames(90)
	var chip: float = a.player.max_hp - a.player.hp
	_check(chip > 5.0 and chip < 20.0, "a blocked special chips about 10%% (took %d)" % int(chip))
	# the ultimate goes through block
	c = await _reset(200.0, 0.0, 300.0)
	c[0].hold["block"] = true
	await _frames(20)
	c[1].once["power_3"] = true
	await _frames(120)
	_check(a.player.max_hp - a.player.hp > 200.0, "the third power is unblockable (took %d)" % int(a.player.max_hp - a.player.hp))


func _test_parry() -> void:
	var c := await _reset(170.0)
	c[1].once["light"] = true
	await _frames(2)   # Rhex's jab winds up (startup 0.08 s); Kael blocks just before it lands
	c[0].hold["block"] = true
	await _frames(20)
	_check(a.player.hp == a.player.max_hp and a.enemy.get_meta("parried", false), "parry: no damage and the attacker is stunned")


func _test_evade() -> void:
	var c := await _reset(170.0)
	c[1].once["heavy"] = true
	await _frames(16)   # the heavy lands at 0.36 s: dash back just before it
	c[0].once["dash_back"] = true
	await _frames(40)
	_check(a.player.hp == a.player.max_hp, "dash back just before a heavy evades it (hp %d)" % int(a.player.hp))


func _test_powers_land() -> void:
	for pair in [[a.player, a.enemy], [a.enemy, a.player]]:
		var atk: Fighter = pair[0]
		var tgt: Fighter = pair[1]
		for i in atk.powers.size():
			var p: Dictionary = atk.powers[i]
			if float(p.get("damage", 0.0)) <= 0.0:
				continue
			var gap := clampf(Fighter.power_reach(p) * 0.6, 160.0, 450.0)
			var c := await _reset(gap, 300.0, 300.0)
			atk.controller = null
			tgt.controller = null
			atk._try_power(i)
			await _frames(110)
			var dmg := tgt.max_hp - tgt.hp
			_check(dmg > 0.0, "%s %s lands on %s at %d px (damage %d)" % [atk.display_name, p.get("name", "?"), tgt.display_name, int(gap), int(dmg)])


func _test_buffer() -> void:
	var c := await _reset(170.0, 100.0, 0.0)
	c[0].once["light"] = true
	await _frames(3)
	c[0].once["power"] = true   # tapped during the jab's startup
	var t0 := 0
	while t0 < 30 and a.player.state != Fighter.S.POWER:
		await _frames(1)
		t0 += 1
	_check(a.player.state == Fighter.S.POWER, "a power tapped mid-combo fires within %.2f s" % (t0 / 60.0))
	await _frames(60)


func _test_no_cross() -> void:
	var crossed := 0
	var ticks := 0
	# AI vs AI with lots of energy (dash powers, ultimates), plus scripted dashes
	await _reset(500.0, 300.0, 300.0)
	a.player.controller = AIController.new(0.9)
	a.enemy.controller = AIController.new(0.9)
	for i in 1500:
		await get_tree().physics_frame
		if a.player.is_alive() and a.enemy.is_alive():
			ticks += 1
			if a.player.position.x >= a.enemy.position.x:
				crossed += 1
		if i % 300 == 0:
			a.player.energy = 300.0
			a.enemy.energy = 300.0
			a.player.hp = a.player.max_hp
			a.enemy.hp = a.enemy.max_hp
	var c := await _reset(300.0, 300.0, 300.0)
	a.player._try_power(1)   # Thunder Step: used to dash straight through
	for i in 60:
		await get_tree().physics_frame
		if a.player.position.x >= a.enemy.position.x:
			crossed += 1
	c = await _reset(300.0)
	for i in 6:
		c[0].once["forward"] = true
		await _frames(12)
		if a.player.position.x >= a.enemy.position.x:
			crossed += 1
	_check(crossed == 0, "fighters never cross (%d crossed ticks in %d)" % [crossed, ticks])


func _test_equal_damage() -> void:
	var kael: Fighter = a.player
	var rhex: Fighter = a.enemy
	for slot in [["light", 0], ["medium", 0], ["heavy", 0]]:
		var mk: Dictionary = kael._make_move(slot[0], slot[1])
		var mr: Dictionary = rhex._make_move(slot[0], slot[1])
		_check(is_equal_approx(float(mk["damage"]), float(mr["damage"])), "%s %d: same damage for both (%d / %d)" % [slot[0], slot[1] + 1, int(mk["damage"]), int(mr["damage"])])
	for i in 3:
		_check(is_equal_approx(float(kael.powers[i]["damage"]), float(rhex.powers[i]["damage"])), "power %d: same damage (%d)" % [i + 1, int(kael.powers[i]["damage"])])
	_check(kael.max_hp == rhex.max_hp, "same HP (%d)" % int(kael.max_hp))
	Settings.current_losses = 0
	Settings.difficulty = 2
	var hard_ai := Settings.damage_mult(true)
	Settings.difficulty = 0
	var easy_ai := Settings.damage_mult(true)
	Settings.difficulty = 1
	_check(hard_ai > 1.0 and easy_ai < 1.0 and Settings.damage_mult(true) == 1.0, "difficulty scales the AI's damage (easy %.2f, hard %.2f)" % [easy_ai, hard_ai])
	# the story's curve rises chapter by chapter, stays under the cap, and eases after defeats
	var curve := []
	for fid in ["fight01", "fight02", "fight03", "fight04"]:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/fights/%s.json" % fid))
		curve.append(float(d.get("ai", 0.0)))
	var rising := true
	for i in range(1, curve.size()):
		rising = rising and curve[i] > curve[i - 1]
	_check(rising, "enemy skill rises fight by fight %s" % str(curve))
	Settings.difficulty = 2
	var top := Settings.enemy_level(curve[-1], 0)
	var eased := Settings.enemy_level(curve[-1], 3)
	Settings.current_losses = 3
	var eased_dmg := Settings.damage_mult(true)
	Settings.current_losses = 0
	Settings.difficulty = 1
	_check(top <= Settings.MAX_AI, "the hardest fight on Hard stays under the cap (%.2f <= %.2f)" % [top, Settings.MAX_AI])
	_check(eased < top - 0.15 and eased_dmg < 1.0, "three defeats ease the fight (skill %.2f -> %.2f, AI damage x%.2f)" % [top, eased, eased_dmg])
