class_name AIController
extends RefCounted
## Simple fighting AI. `level` 0..1 controls reaction speed, blocking and aggression.

var level := 0.5
var _think := 0.0
var _plan := "approach"
var _plan_time := 0.0
var _press := ""
var _block_time := 0.0
var rng := RandomNumberGenerator.new()


func _init(difficulty: float = 0.5) -> void:
	level = clampf(difficulty, 0.0, 1.0)
	rng.randomize()


func get_input(f: Fighter, delta: float) -> Dictionary:
	var out := {"move": 0.0, "jump": false, "light": false, "heavy": false, "block": false, "power_1": false, "power_2": false}
	var opp := f.opponent
	if opp == null or not opp.is_alive():
		return out
	var dx := opp.position.x - f.position.x
	var dist := absf(dx)
	var toward := signf(dx)

	# Reactive blocking against attacks and incoming projectiles.
	_block_time = maxf(0.0, _block_time - delta)
	var threatened := opp.state in [Fighter.S.ATTACK, Fighter.S.POWER] and dist < 340.0 and opp.state_time < 0.15
	for p in f.get_tree().get_nodes_in_group("projectiles"):
		if p.owner_fighter == opp and absf(p.position.x - f.position.x) < 380.0:
			threatened = true
	# Defensive powers (e.g. Stone Bulwark) against projectiles and pulls.
	var danger := false
	for p in f.get_tree().get_nodes_in_group("projectiles"):
		if p.owner_fighter == opp and absf(p.position.x - f.position.x) < 650.0:
			danger = true
	if opp.state == Fighter.S.POWER and opp.state_time < 0.25 and opp.power_def.get("type", "") in ["pull", "projectile"]:
		danger = true
	if danger and f.state in [Fighter.S.IDLE, Fighter.S.WALK, Fighter.S.BLOCK]:
		for i in mini(2, f.powers.size()):
			var dp: Dictionary = f.powers[i]
			if dp.get("ai_use", "") == "defend" and f.energy >= float(dp.get("cost", 30)) \
					and not f.has_status("anchored") and rng.randf() < 0.15 + level * 0.3:
				out["power_%d" % (i + 1)] = true
				return out
	var see_mult := 0.35 if opp.is_veiled() else 1.0   # hard to read a veiled opponent
	if threatened and _block_time <= 0.0 and rng.randf() < (0.035 + level * 0.09) * see_mult:
		_block_time = 0.35 + rng.randf() * 0.3
	if _block_time > 0.0:
		out["block"] = true
		return out

	_think -= delta
	_plan_time -= delta
	if _think <= 0.0:
		_think = lerpf(0.55, 0.18, level) * rng.randf_range(0.7, 1.3)
		_decide(f, dist)

	match _plan:
		"approach":
			out["move"] = toward
		"retreat":
			out["move"] = -toward
		"jump_in":
			out["move"] = toward
			out["jump"] = _consume("jump")
		"combo":
			if dist > 175.0:
				out["move"] = toward
			else:
				out["light"] = rng.randf() < 0.5
				out["heavy"] = rng.randf() < 0.06 + level * 0.06
		"heavy":
			if dist > 190.0:
				out["move"] = toward
			else:
				out["heavy"] = _consume("heavy")
		"power_1":
			out["power_1"] = _consume("power_1")
		"power_2":
			if dist > float(_range_of(f, 1)):
				out["move"] = toward
			else:
				out["power_2"] = _consume("power_2")
		"wait":
			pass
	return out


func _consume(what: String) -> bool:
	if _press == what:
		_press = ""
		return true
	return false


func _range_of(f: Fighter, i: int) -> float:
	if i < f.powers.size():
		var p: Dictionary = f.powers[i]
		if p.get("type", "") == "burst":
			return p.get("radius", 250.0) * 0.8
		if p.get("type", "") == "dash":
			return 520.0
	return 2000.0


func _decide(f: Fighter, dist: float) -> void:
	var r := rng.randf()
	# Counter powers (e.g. Clear Sight) are used when there's something to dispel.
	for i in mini(2, f.powers.size()):
		var p: Dictionary = f.powers[i]
		if p.get("ai_use", "") == "dispel" and f.energy >= float(p.get("cost", 30)) and not f.has_status(p.get("status", "")):
			var illusions: bool = f.opponent.has_status("veil")
			for c in f.get_tree().get_nodes_in_group("clones"):
				if c.side != f.side:
					illusions = true
			if illusions and r < 0.4 + level * 0.5:
				_choose("power_%d" % (i + 1), "power_%d" % (i + 1))
				return
	# Keep enough energy in reserve for a defensive power, if the fighter has one.
	var reserve := 0.0
	for dp in f.powers:
		if dp.get("ai_use", "") == "defend":
			reserve = float(dp.get("cost", 30))
	var can_p1: bool = f.powers.size() > 0 and f.energy >= float(f.powers[0].get("cost", 30)) + reserve and f.powers[0].get("ai_use", "") not in ["dispel", "defend"]
	var can_p2: bool = f.powers.size() > 1 and f.energy >= float(f.powers[1].get("cost", 40)) + reserve and f.powers[1].get("ai_use", "") not in ["dispel", "defend"]
	if can_p2 and r < 0.18 + level * 0.15 and dist < _range_of(f, 1) + 150.0:
		_choose("power_2", "power_2")
	elif can_p1 and (dist > 380.0 or f.powers[0].get("type", "") in ["buff", "summon"]) and r < 0.3 + level * 0.2:
		_choose("power_1", "power_1")
	elif dist > 420.0:
		_choose("jump_in" if r > 0.85 else "approach", "jump")
	elif dist < 200.0:
		if r < 0.5 + level * 0.2:
			_choose("combo", "")
		elif r < 0.72:
			_choose("heavy", "heavy")
		elif r < 0.85:
			_choose("retreat", "")
		else:
			_choose("wait", "")
	else:
		_choose("approach" if r < 0.75 else "wait", "")


func _choose(plan: String, press: String) -> void:
	_plan = plan
	_press = press
