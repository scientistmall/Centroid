class_name AIController
extends RefCounted
## MCOC-style fighting AI. `level` 0..1 sets reaction time, how often it blocks / parries /
## evades, and aggression. It uses the same inputs as the player: light (combo), forward
## (medium in range, dash when far), heavy, dash back, block, powers. It reacts to what it sees
## after a human-like delay, never instantly.

var level := 0.5
var _think := 0.0
var _plan := "approach"
var _plan_time := 0.0
var _press := ""
var _block_time := 0.0
var rng := RandomNumberGenerator.new()
var _goal := 1    # which power (1..3) the AI is saving bars for; re-rolled after each power
var _threat_id := ""        # the opponent action currently being reacted to
var _react_at := -1.0       # when the planned reaction (block / evade) starts
var _react := ""            # "block" or "evade"
var _clock := 0.0
var _tap := 0.0             # light-attack tapping rhythm in a combo
var _combo_left := 0        # hits still to throw in the committed combo
var _seen_free := -1.0      # the last "freed after a string" moment acted on
var _breath := 0.0          # a short pause after a combo or a block (readable, punishable)


func _init(difficulty: float = 0.5) -> void:
	level = clampf(difficulty, 0.0, 1.0)
	rng.randomize()


func reaction_time() -> float:
	return lerpf(0.32, 0.12, level)


func get_input(f: Fighter, delta: float) -> Dictionary:
	_clock += delta
	var out := {"forward": false, "dash_back": false, "light": false, "heavy": false, "block": false,
		"power_1": false, "power_2": false, "power_3": false}
	var opp := f.opponent
	if opp == null or not opp.is_alive():
		return out
	var dist := absf(opp.position.x - f.position.x)

	# ---- reacting to the opponent (after a reaction delay, decided once per threat)
	var tid := ""
	var special := false
	if opp.state == Fighter.S.ATTACK and dist < 380.0:
		# one id per attack (its kind and the moment it started)
		tid = "a_%s_%d_%d" % [opp.move_kind, opp.chain_index, int((opp.clock - opp.state_time) * 1000.0)]
	elif opp.state == Fighter.S.POWER and opp.state_time < 0.4:
		tid = "p_%d" % int((opp.clock - opp.state_time) * 1000.0)
		special = true
	for pr in f.get_tree().get_nodes_in_group("projectiles"):
		if pr.owner_fighter == opp and absf(pr.position.x - f.position.x) < 520.0:
			tid = "pr_%d" % pr.get_instance_id()
			special = true
	if tid != "" and tid != _threat_id and _block_time > 0.0:
		# already guarding when the attack comes: keep the guard up through it (re-raising it
		# now would land in the parry window and turn an ordinary block into a parry)
		_threat_id = tid
		_block_time = maxf(_block_time, 0.45)
		_react = ""
	if tid != "" and tid != _threat_id:
		_threat_id = tid
		var see := 0.35 if opp.is_veiled() else 1.0
		var unblockable: bool = special and opp.state == Fighter.S.POWER and opp.power_def.get("unblockable", false)
		var r := rng.randf()
		var p_block := (0.3 + level * 0.45) * see * (0.5 if special else 1.0)
		var p_evade := (0.05 + level * 0.15) * see
		if unblockable or (opp.move_kind == "heavy" and opp.state == Fighter.S.ATTACK):
			p_evade += 0.15 + level * 0.25   # heavies and unblockables: dash back instead
			p_block = 0.0 if unblockable else p_block * 0.5
		if r < p_evade:
			_react = "evade"
		elif r < p_evade + p_block:
			_react = "block"
		else:
			_react = ""
		_react_at = _clock + reaction_time() * rng.randf_range(0.8, 1.25)
		# a reactive block starts no earlier than the parry window allows, so it is an ordinary
		# block; a deliberate parry (timed into the window) is a separate roll, on harder levels
		if _react == "block" and opp.state == Fighter.S.ATTACK:
			var hit_at: float = _clock - opp.state_time + float(opp.move.get("startup", 0.1))
			var parry := level >= 0.6 and opp.move_kind != "heavy" and rng.randf() < (level - 0.55) * 0.6
			if parry:
				_react_at = hit_at - Fighter.PARRY_WINDOW * 0.6
			else:
				_react_at = maxf(_react_at, hit_at - Fighter.PARRY_WINDOW + 0.02)
	if _react != "" and _clock >= _react_at:
		if _react == "evade":
			out["dash_back"] = true
			_react = ""
			return out
		_block_time = 0.3 + rng.randf() * 0.35
		_react = ""
	# freed after the opponent's string (Fighter._end_string): take the turn, decide again now,
	# and often put the guard up instead of standing there to be dashed into again
	var freed_at: float = f.get_meta("freed_at", -1.0)
	if freed_at >= 0.0 and freed_at != _seen_free and f.clock - freed_at < 0.4 \
			and f.state not in [Fighter.S.HURT, Fighter.S.BLOCKSTUN]:
		_seen_free = freed_at
		_think = 0.0
		_combo_left = 0
		_breath = 0.0
		if rng.randf() < 0.3 + level * 0.35:
			_block_time = maxf(_block_time, rng.randf_range(0.3, 0.5))
	_block_time = maxf(0.0, _block_time - delta)
	if _block_time > 0.0:
		out["block"] = true
		return out

	# ---- defensive powers (e.g. Stone Bulwark) against projectiles and pulls
	var danger := false
	for pr2 in f.get_tree().get_nodes_in_group("projectiles"):
		if pr2.owner_fighter == opp and absf(pr2.position.x - f.position.x) < 650.0:
			danger = true
	if opp.state == Fighter.S.POWER and opp.state_time < 0.25 and opp.power_def.get("type", "") in ["pull", "projectile"]:
		danger = true
	if danger and f.state in [Fighter.S.IDLE, Fighter.S.WALK, Fighter.S.BLOCK]:
		for i in mini(2, f.powers.size()):
			var dp: Dictionary = f.powers[i]
			if dp.get("ai_use", "") == "defend" and f.energy >= float(dp.get("cost", 30)) \
					and not f.has_status("anchored") and rng.randf() < 0.02 + level * 0.05:
				out["power_%d" % (i + 1)] = true
				return out

	# ---- its own plan (kept while a combo is being thrown: no change of mind mid-string)
	_think -= delta
	_plan_time -= delta
	_breath = maxf(0.0, _breath - delta)
	if _breath > 0.0:
		return out
	var committed := _plan == "combo" and _combo_left > 0 and f.state in [Fighter.S.ATTACK, Fighter.S.IDLE, Fighter.S.DASH]
	if _think <= 0.0 and not committed:
		_think = lerpf(0.5, 0.2, level) * rng.randf_range(0.8, 1.2)
		_decide(f, dist)
		if _plan == "combo":
			var r := rng.randf()
			_combo_left = 5 if r < 0.25 + level * 0.3 else (3 if r < 0.75 else 2)

	match _plan:
		"approach":
			if dist > Fighter.MEDIUM_RANGE:
				out["forward"] = f.state == Fighter.S.IDLE   # dash in
			else:
				_plan = "combo"
		"retreat":
			out["dash_back"] = _consume("dash_back")
		"combo":
			if dist > 280.0:
				out["forward"] = f.state == Fighter.S.IDLE
			elif _combo_left > 0:
				# a steady rhythm, one press per hit: light, light, light, then the mediums
				_tap -= delta
				if _tap <= 0.0 and f.state in [Fighter.S.IDLE, Fighter.S.ATTACK]:
					_tap = 0.14
					out["light"] = true
					_combo_left -= 1
					if _combo_left == 0:
						_breath = rng.randf_range(0.35, 0.6) * lerpf(1.3, 0.7, level)
						_plan = "wait"
		"heavy":
			if dist > 250.0:
				out["forward"] = f.state == Fighter.S.IDLE
			else:
				out["heavy"] = _consume("heavy")
		"power_1", "power_2", "power_3":
			var k := int(_plan.substr(6)) - 1
			if dist > float(_range_of(f, k)):
				out["forward"] = f.state == Fighter.S.IDLE
			else:
				out[_plan] = _consume(_plan)
		"wait":
			pass
	return out


func _consume(what: String) -> bool:
	if _press == what:
		_press = ""
		if what.begins_with("power_"):
			var g := rng.randf()
			_goal = 1 if g < 0.4 else (2 if g < 0.8 else 3)
		return true
	return false


func _range_of(f: Fighter, i: int) -> float:
	if i < f.powers.size():
		var p: Dictionary = f.powers[i]
		if p.get("type", "") == "burst":
			return p.get("radius", 250.0) * 0.8
		if p.get("type", "") == "dash":
			return 520.0
		if p.get("type", "") == "lash":
			return p.get("reach", 400.0) - 20.0
		if p.get("type", "") == "drain":
			return p.get("range", 650.0)
	return 2000.0


## Whether power i makes sense right now (ignores energy).
func _power_ok(f: Fighter, i: int, dist: float) -> bool:
	var p: Dictionary = f.powers[i]
	match p.get("type", ""):
		"buff", "summon":
			return true
		"lash":
			return dist > 140.0 and dist <= _range_of(f, i)
		"drain":
			return dist <= _range_of(f, i) and f.opponent.energy >= float(p.get("amount", 35)) * 0.8
		"burst", "dash":
			return dist < _range_of(f, i) + 150.0
		"pull":
			return dist > 150.0
		_:
			return dist > 380.0 or i == 1


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
	# Cleansing powers (e.g. Purify) are used when poisoned or cursed.
	for i in mini(2, f.powers.size()):
		var cp: Dictionary = f.powers[i]
		if cp.get("ai_use", "") == "cleanse" and f.energy >= float(cp.get("cost", 30)) \
				and (f.has_status("poison") or f.has_status("cursed")) and r < 0.45 + level * 0.45:
			_choose("power_%d" % (i + 1), "power_%d" % (i + 1))
			return
	# Keep enough energy in reserve for a defensive power, if the fighter has one.
	var reserve := 0.0
	for dp in f.powers:
		if dp.get("ai_use", "") == "defend":
			reserve = float(dp.get("cost", 30))
	var special := ["dispel", "defend", "cleanse"]
	# Powers: the fighter saves bars toward a goal (1..3). With the goal reached it fires the
	# goal power if it fits the moment, otherwise the best other affordable power that does.
	var bars := f.bars_full()
	# never save toward a situational power (cleanse / dispel / defend): those fire on their own
	while _goal >= 1 and _goal < f.powers.size() and f.powers[_goal - 1].get("ai_use", "") in special:
		_goal += 1
	_goal = mini(_goal, f.powers.size())
	var pick := -1
	if bars >= _goal and r < 0.55 + level * 0.3:
		var order := [_goal - 1]
		for k in range(bars - 1, -1, -1):
			if k != _goal - 1:
				order.append(k)
		for k in order:
			if k >= 0 and k < f.powers.size() and f.energy >= float(f.powers[k].get("cost", 100.0)) + (reserve if k < 2 else 0.0) - 0.5 \
					and f.powers[k].get("ai_use", "") not in special and _power_ok(f, k, dist):
				pick = k
				break
	if pick >= 0:
		_choose("power_%d" % (pick + 1), "power_%d" % (pick + 1))
	elif dist > 420.0:
		_choose("approach", "")
	elif dist < 260.0:
		if r < 0.5 + level * 0.2:
			_choose("combo", "")
		elif r < 0.72:
			_choose("heavy", "heavy")
		elif r < 0.85:
			_choose("retreat", "dash_back")
		else:
			_choose("wait", "")
	else:
		_choose("approach" if r < 0.75 else "wait", "")


func _choose(plan: String, press: String) -> void:
	_plan = plan
	_press = press
