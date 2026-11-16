class_name Fighter
extends Node2D
## One fighter: MCOC-style mechanics. Driven by a controller (player or AI) that returns an
## input Dictionary each tick:
##   light / forward / heavy / dash_back / power / power_1..3: bool (just pressed)
##   block: bool (held)
## `forward` is the swipe toward the opponent: a medium attack in range, a dash forward when far.
## Presses are buffered for BUFFER seconds and run on the first tick they are legal, so a tap
## during an attack, a stun or hit-stop is not lost.
## Rules: the two fighters never cross (fixed sides per round); blocking stops basic attacks
## completely (specials chip 10%, the third power is unblockable); blocking just before a hit
## parries (the attacker is stunned); the start of a dash back evades. Every fighter uses the
## same move numbers (MOVE_TABLE) and 1000 HP; difficulty scales player/AI damage.

signal hp_changed(f: Fighter)
signal energy_changed(f: Fighter)
signal knocked_out(f: Fighter)
signal got_hit(f: Fighter, heavy: bool)
signal power_used(f: Fighter, power_name: String)
## A power (not a normal attack) connected: drives the impact frame.
signal special_hit(f: Fighter, attacker: Fighter)
## Blocked just in time (the attacker is stunned) / dodged by a dash back.
signal parried(f: Fighter, attacker: Fighter)
signal evaded(f: Fighter)

enum S { IDLE, WALK, AIR, ATTACK, BLOCK, BLOCKSTUN, HURT, KO, POWER, WIN, FROZEN, DASH }

const GRAVITY := 3400.0
const MAX_ENERGY := 300.0
const BAR := 100.0               # one power bar; power N costs N bars
const BODY_HALF_W := 52.0  # 3D bodies are wider than the old silhouettes
const BODY_H := 285.0
const PASSIVE_ENERGY := 4.0      # per second
const PUSH_FRICTION := 2600.0
const POISON_DPS := 15.0
const HP := 1000.0               # every fighter: fair fights
const BUFFER := 0.25             # seconds a press waits for its first legal tick
const POWER_BUFFER := 0.6        # ... and a power tap
const MIN_GAP := 112.0           # closest the two bodies get (they never pass each other)
const PARRY_WINDOW := 0.15       # block started this soon before a hit = parry
const PARRY_STUN := 0.8
const EVADE_WINDOW := 0.15       # the start of a dash back dodges hits
const DASH_FWD := Vector2(1500.0, 0.2)    # speed, time
const DASH_BACK := Vector2(1350.0, 0.2)
const MEDIUM_RANGE := 330.0      # a swipe toward within this distance is a medium attack
## Shared frame data and damage by move slot (anim and model come from each fighter's json).
## [startup, active, recovery, damage, reach, stun, knock, step]
const MOVE_TABLE := {
	"light": [[0.08, 0.07, 0.17, 30.0, 185.0, 0.34, 120.0, 40.0], [0.08, 0.07, 0.17, 32.0, 195.0, 0.34, 130.0, 40.0],
		[0.09, 0.07, 0.2, 36.0, 195.0, 0.38, 150.0, 30.0]],
	"medium": [[0.12, 0.08, 0.24, 48.0, 215.0, 0.44, 160.0, 70.0], [0.13, 0.08, 0.3, 52.0, 220.0, 0.5, 420.0, 60.0]],
	"heavy": [[0.36, 0.1, 0.38, 110.0, 230.0, 0.6, 520.0, 70.0]],
}
const POWER_DAMAGE := [130.0, 230.0, 380.0]
const POWER_STUN := [[0.5, 300.0], [0.7, 460.0], [1.0, 560.0]]   # [stun, knock] by power level
const POWER_REACH := 600.0       # lock-on reach of every close-range power (bursts, dashes)
const SP3_WINDUP := 0.6          # the ultimate's cinematic: the opponent is frozen while it winds up

var ground_y := 880.0
var stage_left := 140.0
var stage_right := 1780.0
## Round start: the fighter charges at a sprint until it blocks, backs off, attacks, or
## reaches fighting range.
var advance := false
const SPRINT_SPEED := 1100.0
const ADVANCE_STOP := 300.0

var data: Dictionary = {}
var char_id := ""
var display_name := ""
var color := Color.WHITE
var element := ""
var weapon := "sword"
var max_hp := 1000.0
var hp := 1000.0
var energy := 0.0
var walk_speed := 430.0
var jump_vel := 1300.0
var powers: Array = []

var opponent: Fighter
var effects_parent: Node
var controller: Object
var facing := 1
var vel := Vector2.ZERO
var state: S = S.FROZEN
var state_time := 0.0
var stun_time := 0.0
var invuln := 0.0
var hitstop := 0.0
var flash := 0.0
var clock := 0.0
var inp: Dictionary = {}

var move: Dictionary = {}
var move_kind := ""
var chain_index := 0
var move_hit := false
var queued := ""
var power_def: Dictionary = {}
var power_index := 0          # which of the three powers is running (2 = the unblockable ultimate)
var power_fired := false
var air_attack_used := false
var _buf: Dictionary = {}        # action -> seconds left in the buffer
var _block_since := -9.0         # clock when the current block started (parry timing)
var dash_dir := 0                # +1 dash forward, -1 dash back (S.DASH)
var _last_pose: Dictionary = {}
var statuses: Dictionary = {}   # status name -> seconds left (veil, clear_sight, ...)
var side := 0                   # 0 = player side, 1 = enemy side
var pull_source: Fighter        # who is pulling us (gravity status)
var shots_fired := 0
var pull_speed := 380.0
# Visuals (shadow-anime rig)
var costume: Dictionary = {}
var sec := Vector2.ZERO          # secondary-motion lag for cloth and hair
var _sec_vel := Vector2.ZERO
var _trail: Array = []           # recent weapon-tip positions (world) for smears
## Set by a 3D model: returns [tip, mid] of the real weapon, relative to `position` (2D px).
var tip_source: Callable
var _emitter: CPUParticles2D     # element particles when charged
var render_3d := false           # true when a 3D puppet draws the body


func setup(fighter_data: Dictionary) -> void:
	data = fighter_data
	char_id = data.get("id", "")
	display_name = data.get("name", char_id.to_upper())
	color = Color(data.get("color", "#ffffff"))
	element = data.get("element", "")
	weapon = data.get("weapon", "sword")
	max_hp = HP
	walk_speed = float(data.get("walk_speed", 430))
	jump_vel = float(data.get("jump_velocity", 1300))
	powers = data.get("powers", [])
	for i in powers.size():
		var pw: Dictionary = powers[i]
		pw["cost"] = BAR * (i + 1)
		pw["damage"] = POWER_DAMAGE[mini(i, 2)] if float(pw.get("damage", 0.0)) > 0.0 else 0.0
		if i < 2:
			pw["startup"] = minf(float(pw.get("startup", 0.2)), 0.08)
		else:
			pw["startup"] = SP3_WINDUP
			pw["unblockable"] = true
		pw.erase("armor")
		pw.erase("launch")   # no juggles (MCOC): a launched fighter could be hit again before landing
		if pw.get("type", "") == "projectile":
			pw["speed"] = 1300.0   # one projectile speed: equally hard to react to for everyone
		if float(pw.get("damage", 0.0)) > 0.0:
			pw["stun"] = POWER_STUN[mini(i, 2)][0]
			pw["knock"] = POWER_STUN[mini(i, 2)][1]
	costume = PortraitArt.look_for(char_id).get("fighter", {})
	if element != "" and _emitter == null:
		_emitter = Vfx.element_emitter(element, color)
		_emitter.z_index = 2
		add_child(_emitter)
	reset_for_round()


func reset_for_round() -> void:
	advance = false
	set_meta("intro_run", false)
	hp = max_hp
	energy = float(data.get("start_energy", 20)) * 3.0
	vel = Vector2.ZERO
	stun_time = 0.0
	invuln = 0.0
	flash = 0.0
	clear_statuses()
	move = {}
	queued = ""
	_buf.clear()
	set_state(S.FROZEN)
	hp_changed.emit(self)
	energy_changed.emit(self)


func set_state(s: S) -> void:
	if advance and s not in [S.IDLE, S.WALK]:
		_stop_advance()   # hit, blocked, attacking, jumping: the charge is over
	state = s
	state_time = 0.0


func is_grounded() -> bool:
	return position.y >= ground_y - 0.5


func is_alive() -> bool:
	return state != S.KO


func hurtbox() -> Rect2:
	var h := BODY_H
	if state == S.KO:
		h = 70.0
	return Rect2(position.x - BODY_HALF_W, position.y - h, BODY_HALF_W * 2, h)


func add_energy(amount: float) -> void:
	if amount > 0.0 and has_status("cursed"):
		amount *= 0.5   # Withering Curse halves energy gain
	var before := energy
	energy = clampf(energy + amount, 0.0, MAX_ENERGY)
	if not is_equal_approx(before, energy):
		energy_changed.emit(self)


# ------------------------------------------------------------------ update

func _physics_process(delta: float) -> void:
	clock += delta
	# read and buffer input every tick, even during hit-stop, so no press is lost
	inp = {}
	if controller and state not in [S.FROZEN, S.KO, S.WIN]:
		inp = controller.get_input(self, delta)
	for k in _buf.keys():
		_buf[k] -= delta
		if _buf[k] <= 0.0:
			_buf.erase(k)
	for k in ["light", "forward", "heavy", "dash_back", "power", "power_1", "power_2", "power_3"]:
		if inp.get(k, false):
			# a power tap is deliberate: it waits longer for the current move to allow it
			_buf[k] = POWER_BUFFER if k.begins_with("power") else BUFFER
	if inp.get("block", false) and state not in [S.BLOCK, S.BLOCKSTUN]:
		if not get_meta("block_held", false):
			_block_since = clock
		set_meta("block_held", true)
	elif not inp.get("block", false):
		set_meta("block_held", false)
	if hitstop > 0.0:
		hitstop -= delta
		queue_redraw()
		return
	state_time += delta
	flash = maxf(0.0, flash - delta * 5.0)
	invuln = maxf(0.0, invuln - delta)
	for k in statuses.keys():
		statuses[k] -= delta
		if statuses[k] <= 0.0:
			statuses.erase(k)
	if has_status("poison") and state not in [S.FROZEN, S.KO, S.WIN] and hp > 1.0:
		hp = maxf(1.0, hp - POISON_DPS * delta)   # poison weakens but never KOs
		hp_changed.emit(self)
	if state not in [S.FROZEN, S.KO, S.WIN]:
		add_energy(PASSIVE_ENERGY * delta)

	match state:
		S.IDLE, S.WALK: _ground_control()
		S.AIR: _air_control()
		S.ATTACK: _attack_update(delta)
		S.BLOCK: _block_update()
		S.BLOCKSTUN, S.HURT: _stun_update(delta)
		S.POWER: _power_update(delta)
		S.DASH: _dash_update(delta)
		S.KO, S.FROZEN, S.WIN: pass

	# Gravity Well: dragged toward the source unless anchored.
	if has_status("gravity") and not has_status("anchored") and pull_source and state != S.KO:
		var dx := pull_source.position.x - position.x
		if absf(dx) > 150.0:
			position.x += signf(dx) * pull_speed * delta

	# physics
	if not is_grounded() or vel.y < 0.0:
		vel.y += GRAVITY * delta
	position += vel * delta
	if position.y >= ground_y:
		position.y = ground_y
		if vel.y > 0.0:
			vel.y = 0.0
			_on_land()
	if is_grounded() and state in [S.HURT, S.BLOCKSTUN, S.KO, S.FROZEN, S.WIN]:
		vel.x = move_toward(vel.x, 0.0, PUSH_FRICTION * delta)
	position.x = clampf(position.x, stage_left, stage_right)
	_keep_side()
	_update_visual_motion(delta)
	var target_alpha := 0.16 if is_veiled() else 1.0
	modulate.a = move_toward(modulate.a, target_alpha, delta * 4.0)
	queue_redraw()


func _sfx(sound: String, db := 0.0) -> void:
	AudioManager.sfx(sound, db)


# ------------------------------------------------------------------ visual motion

## Springy cloth/hair lag and the weapon smear trail.
func _update_visual_motion(delta: float) -> void:
	var target := Vector2(clampf(-vel.x * 0.05, -40.0, 40.0), clampf(-vel.y * 0.02, -30.0, 30.0))
	target.x += sin(clock * 1.7) * 3.0
	_sec_vel += (target - sec) * 90.0 * delta
	_sec_vel *= exp(-9.0 * delta)
	sec += _sec_vel * delta
	# charged element particles stream off the weapon
	if _emitter:
		var charged := state == S.POWER or (not tip_source.is_valid() and (energy >= MAX_ENERGY * 0.999 or (state == S.ATTACK and move_kind == "heavy")))
		_emitter.emitting = charged and state != S.KO
		if tip_source.is_valid():
			_emitter.position = tip_source.call()[0]
		elif weapon != "none":
			_emitter.position = FighterPainter.weapon_tip(current_pose(), facing, weapon) * 0.85
	var swinging := false
	if state == S.ATTACK and not tip_source.is_valid():
		# (3D fighters fight unarmed: no blade smear on punches and kicks)
		var tm := _move_times()
		swinging = state_time >= tm.x * 0.9 and state_time <= tm.x + tm.y + 0.04
	elif state == S.POWER and power_def.get("type", "") in ["dash", "lash", "burst"]:
		swinging = true
	if swinging and weapon != "none":
		# record the blade tip and a point 40% down the blade (pairs) for a crescent smear
		if tip_source.is_valid():
			var tm3: Array = tip_source.call()
			_trail.append(position + tm3[0])
			_trail.append(position + tm3[1])
		else:
			var pose := current_pose()
			var j := FighterPainter.joints(pose, facing)
			var tip := FighterPainter.weapon_tip(pose, facing, weapon)
			_trail.append(position + tip)
			_trail.append(position + j["hand_f"].lerp(tip, 0.4))
		while _trail.size() > 12:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
		_trail.pop_front()


# ------------------------------------------------------------------ statuses

func has_status(n: String) -> bool:
	return statuses.has(n)


func add_status(n: String, seconds: float) -> void:
	if n in ["poison", "cursed"] and has_status("purified"):
		return   # Purify protects for a few seconds
	statuses[n] = maxf(statuses.get(n, 0.0), seconds)


func clear_statuses() -> void:
	statuses.clear()
	modulate.a = 1.0


## Veil only works while the opponent can't see through it.
func is_veiled() -> bool:
	return has_status("veil") and not (opponent != null and opponent.has_status("clear_sight"))


func damage_mult() -> float:
	return 1.2 if is_veiled() else 1.0


## Removes illusions (clones) that belong to the other side.
func dispel_enemy_illusions() -> void:
	if opponent:
		opponent.statuses.erase("veil")
	for c in get_tree().get_nodes_in_group("clones"):
		if c.side != side:
			c.pop()


func _face_opponent() -> void:
	if opponent and absf(opponent.position.x - position.x) > 4.0:
		facing = 1 if opponent.position.x > position.x else -1


## Buffered press: true (and used up) if `k` was pressed within the last BUFFER seconds.
func _take(k: String) -> bool:
	if _buf.has(k):
		_buf.erase(k)
		return true
	return false


func _has_buf(k: String) -> bool:
	return _buf.has(k)


## The fighters never pass each other: the player side stays left of the enemy side, at least
## MIN_GAP apart. When one is against a wall the other is held off instead.
func _keep_side() -> void:
	if opponent == null or is_in_group("clones") or not is_instance_valid(opponent):
		return
	if opponent.state == S.KO or state == S.KO:
		return
	var left := side == 0
	if left and position.x > opponent.position.x - MIN_GAP:
		position.x = maxf(stage_left, opponent.position.x - MIN_GAP)
		if position.x > opponent.position.x - MIN_GAP:   # pinned at the wall: move the other
			opponent.position.x = minf(stage_right, position.x + MIN_GAP)
		if vel.x > 0.0:
			vel.x = 0.0
	elif not left and position.x < opponent.position.x + MIN_GAP:
		position.x = minf(stage_right, opponent.position.x + MIN_GAP)
		if position.x < opponent.position.x + MIN_GAP:
			opponent.position.x = maxf(stage_left, position.x - MIN_GAP)
		if vel.x < 0.0:
			vel.x = 0.0


## Is this fighter guarding right now (or about to, with block held)?
func is_guarding() -> bool:
	if state in [S.BLOCK, S.BLOCKSTUN]:
		return true
	if not get_meta("block_held", false):
		return false
	if state in [S.IDLE, S.WALK]:
		return true
	if state == S.ATTACK and move_kind != "air":
		var tm := _move_times()
		return state_time >= tm.x + tm.y   # recovery can be blocked out of
	return false


func _ground_control() -> void:
	_face_opponent()
	air_attack_used = false
	if advance:
		var acted: bool = inp.get("block", false) or _has_buf("light") or _has_buf("forward") \
			or _has_buf("heavy") or _has_buf("dash_back") or _has_buf("power") or _has_buf("power_1") \
			or _has_buf("power_2") or _has_buf("power_3")
		var near := opponent != null and absf(opponent.position.x - position.x) <= ADVANCE_STOP
		if acted or near:
			_stop_advance()
			vel.x = 0.0
		else:
			vel.x = facing * SPRINT_SPEED
			set_meta("intro_run", true)
			set_meta("run_rate", 1.3)
			if state != S.WALK:
				state = S.WALK
			return
	vel.x = 0.0
	if state == S.WALK:
		state = S.IDLE
	if _neutral_action():
		return
	if inp.get("block", false):
		set_state(S.BLOCK)


## What a fighter can start from neutral (idle, end of a block, end of a stun), in MCOC
## priority: specials, dash back, attacks, dash forward. True if something started.
func _neutral_action() -> bool:
	if _take("power") and _try_power(bars_full() - 1):
		return true
	for i in 3:
		if _take("power_%d" % (i + 1)) and _try_power(i):
			return true
	if _take("dash_back"):
		_start_dash(-1)
		return true
	if _take("heavy"):
		_start_attack("heavy", 0)
		return true
	if _take("light"):
		_start_attack("light", 0)
		return true
	if _take("forward"):
		if opponent and absf(opponent.position.x - position.x) <= MEDIUM_RANGE:
			_start_attack("medium", 0)
		else:
			_start_dash(1)
		return true
	return false


func _stop_advance() -> void:
	advance = false
	set_meta("intro_run", false)


func _start_dash(dir: int) -> void:
	dash_dir = dir
	_face_opponent()
	set_state(S.DASH)
	_sfx("dash", -8.0)


func _dash_update(_delta: float) -> void:
	var d := DASH_FWD if dash_dir > 0 else DASH_BACK
	var t := state_time
	if t < d.y:
		vel.x = facing * dash_dir * d.x * (1.0 - 0.5 * t / d.y)
		# a dash forward stops at the opponent (they never pass each other)
		if dash_dir > 0 and opponent and absf(opponent.position.x - position.x) <= MIN_GAP + 30.0:
			vel.x = 0.0
			set_state(S.IDLE)
	else:
		vel.x = 0.0
		set_state(S.IDLE)
		# dash forward flows straight into an attack if one was pressed during it
		_neutral_action()


## The start of a dash back is evasive (MCOC dexterity).
func is_evading() -> bool:
	return state == S.DASH and dash_dir < 0 and state_time <= EVADE_WINDOW


func _air_control() -> void:
	pass   # (no jumping in MCOC rules: AIR is only a knock-up)


func _block_update() -> void:
	_face_opponent()
	vel.x = 0.0
	# specials and dash back can be used straight out of a block
	if _has_buf("power") or _has_buf("power_1") or _has_buf("power_2") or _has_buf("power_3") or _has_buf("dash_back"):
		if _neutral_action():
			return
	if not inp.get("block", false):
		set_state(S.IDLE)
		_neutral_action()


func _stun_update(delta: float) -> void:
	stun_time -= delta
	if stun_time <= 0.0 and is_grounded():
		if state == S.BLOCKSTUN and inp.get("block", false):
			set_state(S.BLOCK)   # keep guarding: no gap between blocked hits
			return
		set_state(S.IDLE)
		if not _neutral_action() and inp.get("block", false):
			set_state(S.BLOCK)


func _on_land() -> void:
	match state:
		S.AIR:
			set_state(S.IDLE)
		S.ATTACK:
			if move_kind == "air":
				set_state(S.IDLE)
		S.KO:
			vel.x *= 0.5


# ------------------------------------------------------------------ attacks

## The fighter's json move for a slot (its animation and hit height); "medium" uses the json's
## heavy chain, the charged "heavy" uses its last heavy move.
func _json_move(kind: String, idx: int) -> Dictionary:
	var mv: Dictionary = data.get("moves", {})
	var src: Array = mv.get("light", []) if kind == "light" else mv.get("heavy", [])
	if src.is_empty():
		return {}
	if kind == "heavy":
		return src[src.size() - 1]
	return src[mini(idx, src.size() - 1)]


func _chain(kind: String) -> Array:
	return MOVE_TABLE.get(kind, [])


## A move: the shared numbers (MOVE_TABLE) over the fighter's own animation and hit height.
func _make_move(kind: String, idx: int) -> Dictionary:
	var row: Array = MOVE_TABLE[kind][idx]
	var m := _json_move(kind, idx).duplicate()
	m["startup"] = row[0]
	m["active"] = row[1]
	m["recovery"] = row[2]
	m["damage"] = row[3]
	m["reach"] = row[4]
	m["stun"] = row[5]
	m["knock"] = row[6]
	m["step"] = row[7]
	m.erase("launch")
	m["slot"] = kind
	return m


func _start_attack(kind: String, idx: int) -> void:
	var chain := _chain(kind)
	if idx >= chain.size():
		return
	move = _make_move(kind, idx)
	move_kind = kind
	chain_index = idx
	move_hit = false
	queued = ""
	_face_opponent()
	set_state(S.ATTACK)
	_sfx("swing_heavy" if kind != "light" else "swing_light", -3.0)


func _move_times() -> Vector3:
	return Vector3(move.get("startup", 0.1), move.get("active", 0.08), move.get("recovery", 0.2))


## MCOC combo: light, light, light, medium, medium (tap through it, or swipe for the mediums).
func _next_in_combo(press: String) -> Array:
	match move_kind:
		"light":
			if press == "light" and chain_index < 2:
				return ["light", chain_index + 1]
			if press in ["light", "forward"]:
				return ["medium", 0]
		"medium":
			if press in ["light", "forward"] and chain_index < 1:
				return ["medium", 1]
	return []


func _attack_update(_delta: float) -> void:
	var tm := _move_times()
	var t := state_time
	if move_kind != "air" and is_grounded():
		if t < tm.x + tm.y:
			vel.x = facing * float(move.get("step", 0.0)) / maxf(0.01, tm.x + tm.y)
		else:
			vel.x = 0.0
	if t >= tm.x and t < tm.x + tm.y and not move_hit:
		_check_melee_hit()
	if t >= tm.x + tm.y and move_kind != "air":
		# after the hit: a special cancels the combo (MCOC), then the next combo hit
		if _has_buf("power") or _has_buf("power_1") or _has_buf("power_2") or _has_buf("power_3"):
			if _neutral_action():
				return
		for press in ["light", "forward"]:
			if _has_buf(press):
				var nx := _next_in_combo(press)
				if not nx.is_empty():
					_take(press)
					_start_attack(nx[0], nx[1])
					return
		if inp.get("block", false):
			set_state(S.BLOCK)
			return
		if _has_buf("dash_back"):
			_take("dash_back")
			_start_dash(-1)
			return
	if t >= tm.x + tm.y + tm.z:
		set_state(S.IDLE if is_grounded() else S.AIR)
		_neutral_action()


func attack_rect(m: Dictionary) -> Rect2:
	var reach: float = m.get("reach", 150.0)
	var hr: Array = m.get("height", [-240, -60])
	var x0 := position.x + facing * 10.0
	var x1 := position.x + facing * reach
	return Rect2(minf(x0, x1), position.y + float(hr[0]), absf(x1 - x0), float(hr[1]) - float(hr[0]))


func _check_melee_hit() -> void:
	if opponent == null:
		return
	var rect := attack_rect(move)
	for c in get_tree().get_nodes_in_group("clones"):
		if c.side != side and rect.intersects(c.hurtbox()):
			c.pop()
	if rect.intersects(opponent.hurtbox()):
		move_hit = true
		var result := opponent.receive_hit(self, move)
		if result != "miss":
			hitstop = 0.07 if move_kind != "heavy" else 0.11
			_spawn_spark(opponent.position + Vector2(-facing * 30, -170), result == "block", move_kind == "heavy")


# ------------------------------------------------------------------ powers

## Full power bars, capped by how many powers the fighter has.
func bars_full() -> int:
	return mini(int(floor(energy / BAR + 0.0001)), powers.size())


func _try_power(i: int) -> bool:
	if i < 0 or i >= powers.size():
		return false
	power_index = i
	var p: Dictionary = powers[i]
	var cost: float = p.get("cost", 30)
	if energy < cost:
		return false
	add_energy(-cost)
	power_def = p
	power_fired = false
	shots_fired = 0
	move_hit = false
	_face_opponent()
	vel.x = 0.0
	# lock on: if the opponent is within the power's reach it lands on them (and the effect is
	# drawn there); otherwise it plays out at the end of its reach, visibly missing
	var reach := power_reach(p)
	var locked := opponent != null and absf(opponent.position.x - position.x) <= reach
	set_meta("power_locked", locked)
	set_meta("power_at", opponent.position if locked else position + Vector2(facing * minf(reach, 900.0), 0.0))
	# a locked dash is fast enough to reach the target within its active time
	set_meta("dash_speed", maxf(float(p.get("speed", 2200.0)),
		(absf(opponent.position.x - position.x) - MIN_GAP) / maxf(0.05, float(p.get("active", 0.2))) + 200.0) if locked else float(p.get("speed", 2200.0)))
	if i == 2 and opponent and locked:
		# the ultimate's cinematic: the opponent is frozen while it winds up (MCOC special 3)
		opponent.hitstop = maxf(opponent.hitstop, float(p.get("startup", SP3_WINDUP)) + 0.05)
	set_state(S.POWER)
	power_used.emit(self, p.get("name", "Power"))
	if Vfx3D.on():
		Vfx3D.charge(self, p)
	_sfx(p.get("sfx", "bolt_cast"))
	return true


## How far a power reaches (px, horizontally) for lock-on.
static func power_reach(p: Dictionary) -> float:
	match String(p.get("type", "")):
		"burst":
			return POWER_REACH
		"lash":
			return float(p.get("reach", 400.0))
		"drain":
			return float(p.get("range", 650.0))
		"dash":
			return POWER_REACH
		"projectile", "pull":
			return 4000.0
	return 0.0


func _power_update(_delta: float) -> void:
	var startup: float = power_def.get("startup", 0.2)
	var active: float = power_def.get("active", 0.1)
	var recovery: float = power_def.get("recovery", 0.3)
	var t := state_time
	var type: String = power_def.get("type", "projectile")
	# every damaging power is untouchable through its wind-up and strike (MCOC specials), whatever
	# its type, so no kit trades better than another
	if float(power_def.get("damage", 0.0)) > 0.0 and t < startup + active:
		invuln = maxf(invuln, 0.05)
	match type:
		"projectile":
			var count := int(power_def.get("count", 1))
			var interval: float = power_def.get("interval", 0.15)
			while shots_fired < count and t >= startup + shots_fired * interval:
				if shots_fired == 0:
					Vfx3D.on_power(self, power_def)
				_spawn_projectile(shots_fired, count)
				shots_fired += 1
		"pull":
			if t >= startup and not power_fired:
				power_fired = true
				Vfx3D.on_power(self, power_def)
				if opponent and not opponent.has_status("anchored"):
					opponent.add_status("gravity", power_def.get("duration", 1.4))
					opponent.pull_source = self
					opponent.pull_speed = power_def.get("pull_speed", 380.0)
				var b := BurstFx.new()
				b.radius = 150.0
				b.color = color
				b.dark_core = true
				if opponent:
					b.position = opponent.position + Vector2(0, -120)
					effects_parent.add_child(b)
		"wall":
			if t >= startup and not power_fired:
				power_fired = true
				Vfx3D.on_power(self, power_def)
				add_status("anchored", power_def.get("duration", 3.0))
				_spawn_wall()
		"dash":
			if t >= startup and not power_fired:
				power_fired = true
				Vfx3D.on_power(self, power_def)
			if t >= startup and t < startup + active:
				invuln = 0.05
				# rush in and strike; stop at the opponent (never through them)
				vel.x = 0.0 if move_hit else facing * float(get_meta("dash_speed", power_def.get("speed", 2200)))
				if not move_hit and opponent and (_dash_rect().intersects(opponent.hurtbox()) \
						or absf(opponent.position.x - position.x) <= MIN_GAP + 30.0):
					move_hit = true
					vel.x = 0.0
					var res := opponent.receive_hit(self, power_def)
					if res != "miss":
						hitstop = 0.08
						_spawn_spark(opponent.position + Vector2(0, -170), res == "block", true)
			elif t >= startup + active:
				vel.x = 0.0
		"buff":
			if t >= startup and not power_fired:
				power_fired = true
				Vfx3D.on_power(self, power_def)
				var status: String = power_def.get("status", "")
				for c in power_def.get("cleanse", []):
					statuses.erase(c)
				var heal: float = power_def.get("heal", 0.0)
				if heal > 0.0:
					hp = minf(max_hp, hp + heal)
					hp_changed.emit(self)
				if status == "veil" and opponent and opponent.has_status("clear_sight"):
					pass  # seen through — the veil fizzles
				else:
					add_status(status, power_def.get("duration", 3.0))
				if status == "clear_sight":
					dispel_enemy_illusions()
				_spawn_burst(power_def.get("radius", 160.0))
		"lash":
			# Long whip strike; can poison (apply_status) or reel the target in (pull_in).
			if t >= startup and not power_fired:
				power_fired = true
				_spawn_lash(position + Vector2(facing * float(power_def.get("reach", 400.0)), -175.0))
			if t >= startup and t < startup + active and not move_hit and opponent:
				var rect := attack_rect(power_def)
				for c in get_tree().get_nodes_in_group("clones"):
					if c.side != side and rect.intersects(c.hurtbox()):
						c.pop()
				if rect.intersects(opponent.hurtbox()):
					move_hit = true
					var res3 := opponent.receive_hit(self, power_def)
					if res3 == "hit":
						_apply_on_hit(opponent)
						if power_def.get("pull_in", false) and opponent.is_alive():
							opponent.position.x = clampf(position.x + facing * 150.0, stage_left, stage_right)
							opponent.vel.x = 0.0
					if res3 != "miss":
						hitstop = 0.08
						_spawn_spark(opponent.position + Vector2(0, -170), res3 == "block", true)
		"drain":
			# Steal energy and curse the target (halved energy gain).
			if t >= startup and not power_fired:
				power_fired = true
				if opponent and absf(opponent.position.x - position.x) <= float(power_def.get("range", 650.0)) \
						and not opponent.has_status("purified"):
					var amt := minf(opponent.energy, float(power_def.get("amount", 105.0)))
					opponent.add_energy(-amt)
					add_energy(amt)
					_apply_on_hit(opponent)
					_spawn_lash(opponent.position + Vector2(0, -160))
					var b2 := BurstFx.new()
					b2.radius = 130.0
					b2.color = color
					b2.dark_core = true
					b2.position = opponent.position + Vector2(0, -150)
					effects_parent.add_child(b2)
		"summon":
			if t >= startup and not power_fired:
				power_fired = true
				Vfx3D.on_power(self, power_def)
				if not (opponent and opponent.has_status("clear_sight")):
					_spawn_clone()
				_spawn_burst(120.0)
		"burst":
			if t >= startup and not power_fired:
				power_fired = true
				Vfx3D.on_power(self, power_def)
				var r: float = power_reach(power_def)
				_spawn_burst(float(power_def.get("radius", 250.0)))
				if opponent and get_meta("power_locked", false) and absf(opponent.position.x - position.x) <= r + 150.0:
					var res2 := opponent.receive_hit(self, power_def)
					if res2 != "miss":
						hitstop = 0.1
						_spawn_spark(opponent.position + Vector2(0, -170), res2 == "block", true)
	if t >= startup + active + recovery:
		set_state(S.IDLE if is_grounded() else S.AIR)


func _dash_rect() -> Rect2:
	return Rect2(position.x - 70, position.y - 260, 140, 240)


func _resolve_overlap() -> void:
	if opponent == null:
		return
	var dx := position.x - opponent.position.x
	if absf(dx) < BODY_HALF_W * 2:
		var dirx := signf(dx) if dx != 0.0 else float(facing)
		position.x = clampf(opponent.position.x + dirx * BODY_HALF_W * 2.2, stage_left, stage_right)


func _spawn_projectile(index: int = 0, count: int = 1) -> void:
	if effects_parent == null:
		return
	var pr := Projectile.new()
	pr.setup(self, opponent, power_def, color)
	var spread: float = power_def.get("y_spread", 0.0)
	var y := float(power_def.get("y", -170)) + (index - (count - 1) / 2.0) * spread
	pr.position = position + Vector2(facing * 90, y)
	effects_parent.add_child(pr)


## Applies a power's on-hit statuses, e.g. {"poison": 4.0} or {"cursed": 4.0}.
func _apply_on_hit(target: Fighter) -> void:
	var st: Dictionary = power_def.get("apply_status", {})
	for k in st:
		target.add_status(k, float(st[k]))


func _spawn_lash(to: Vector2) -> void:
	if effects_parent == null:
		return
	Vfx3D.on_lash(self, position + Vector2(facing * 40.0, -190.0), to)
	var l := LashFx.new()
	l.from = position + Vector2(facing * 40.0, -190.0)
	l.to = to
	l.color = color
	effects_parent.add_child(l)


func _spawn_wall() -> void:
	if effects_parent == null:
		return
	var w := StoneWall.new()
	w.side = side
	w.color = color
	w.life = power_def.get("duration", 3.0)
	w.position = Vector2(clampf(position.x + facing * 120.0, stage_left, stage_right), ground_y)
	effects_parent.add_child(w)


func _spawn_clone() -> void:
	if effects_parent == null or opponent == null:
		return
	var c := CloneFighter.new()
	c.ground_y = ground_y
	c.stage_left = stage_left
	c.stage_right = stage_right
	c.setup(data)
	c.side = side
	c.life = power_def.get("duration", 6.0)
	c.controller = AIController.new(0.75)
	c.opponent = opponent
	c.effects_parent = effects_parent
	c.position = Vector2(clampf(opponent.position.x - opponent.facing * 260.0, stage_left, stage_right), ground_y)
	effects_parent.add_child(c)
	c.release()


func _spawn_burst(r: float) -> void:
	if effects_parent == null:
		return
	var b := BurstFx.new()
	b.radius = r
	b.color = color
	b.dark_core = element == "black_flame"
	b.position = position + Vector2(0, -120)
	effects_parent.add_child(b)


func _spawn_spark(at: Vector2, blocked: bool, heavy: bool) -> void:
	if effects_parent == null:
		return
	if Vfx3D.on():
		Vfx3D.on_hit(at, color, blocked, heavy, element)
		return
	var s := HitSpark.new()
	s.position = at
	s.color = Color(0.8, 0.85, 1.0) if blocked else color
	s.big = heavy
	effects_parent.add_child(s)
	# element-flavoured particles on impact
	var kind := "sparks"
	match element:
		"black_flame": kind = "embers"
		"stone", "gravity": kind = "dust"
		"mist": kind = "mist"
		"moonlight": kind = "motes"
		"poison": kind = "drips"
	Vfx.burst(effects_parent, at, Color(0.8, 0.85, 1.0) if blocked else color, "sparks" if blocked else kind, 1.3 if heavy else 0.8)


# ------------------------------------------------------------------ damage

## Returns "hit", "block", "parry" or "miss".
func receive_hit(attacker: Fighter, m: Dictionary) -> String:
	if state == S.KO or invuln > 0.0 or state == S.FROZEN:
		return "miss"
	var special := m.has("cost")
	if is_evading() and not m.get("unblockable", false):
		evaded.emit(self)
		return "miss"
	var dmg: float = float(m.get("damage", 40.0)) * attacker.damage_mult() * Settings.damage_mult(attacker.side == 1)
	var stun: float = m.get("stun", 0.3)
	var knock: float = m.get("knock", 180.0)
	if has_status("anchored"):
		knock = 0.0
	var away := 1.0 if position.x >= attacker.position.x else -1.0
	if is_guarding() and not m.get("unblockable", false):
		# parry: block started just before a basic hit lands -> the attacker is stunned
		if not special and m.get("slot", "") != "heavy" and clock - _block_since <= PARRY_WINDOW \
				and attacker.state == S.ATTACK:
			parried.emit(self, attacker)
			attacker.stun_time = PARRY_STUN
			attacker.vel.x = -away * 120.0
			attacker.set_state(S.HURT)
			attacker.set_meta("parried", true)
			add_energy(10.0)
			set_state(S.BLOCK)
			_sfx("block", 0.0)
			return "parry"
		if special:
			hp = maxf(1.0, hp - dmg * 0.10)   # specials chip through a block
			hp_changed.emit(self)
		stun_time = stun * 0.5
		vel.x = away * knock * (0.5 if m.get("slot", "") == "heavy" else 0.3)
		add_energy(7.0)
		attacker.add_energy(5.0)
		set_state(S.BLOCKSTUN)
		_sfx("block", -2.0)
		return "block"
	hp = maxf(0.0, hp - dmg)
	flash = 1.0
	add_energy(9.0)
	attacker.add_energy(13.0)
	hp_changed.emit(self)
	var heavy := dmg >= 90.0
	got_hit.emit(self, heavy)
	if m.has("cost"):
		special_hit.emit(self, attacker)
	_sfx("hit_heavy" if heavy else "hit_light")
	if m.has("hit_sfx"):
		_sfx(m["hit_sfx"], -3.0)
	if side == 0:
		Settings.vibrate(60 if heavy else 25)
	if hp <= 0.0:
		set_state(S.KO)
		vel = Vector2(away * 520.0, -780.0)
		knocked_out.emit(self)
		_sfx("ko")
		Settings.vibrate(200)
		return "hit"
	# Armoured powers (e.g. big cleaves) keep going through hits.
	if state == S.POWER and power_def.get("armor", false) and not power_fired:
		return "hit"
	stun_time = stun
	vel.x = away * knock
	var launch: float = m.get("launch", 0.0)
	if launch > 0.0 and not has_status("anchored"):
		vel.y = -launch
	set_state(S.HURT)
	return "hit"


func celebrate() -> void:
	if state != S.KO:
		vel.x = 0.0
		set_state(S.WIN)


func freeze() -> void:
	if state != S.KO:
		vel.x = 0.0
		set_state(S.FROZEN)


func release() -> void:
	if state == S.FROZEN:
		set_state(S.IDLE)


# ------------------------------------------------------------------ visuals

func current_pose() -> Dictionary:
	match state:
		S.IDLE, S.FROZEN:
			return Poses.idle_breath(clock)
		S.WALK:
			return Poses.walk_cycle(clock, signf(vel.x) * facing)
		S.AIR:
			return Poses.get_pose("air")
		S.BLOCK, S.BLOCKSTUN:
			return Poses.get_pose("block")
		S.HURT:
			return Poses.get_pose("hurt")
		S.KO:
			return Poses.blend(Poses.get_pose("hurt"), Poses.get_pose("ko"), state_time * 3.0)
		S.WIN:
			return Poses.blend(Poses.get_pose("idle"), Poses.get_pose("win"), state_time * 2.5)
		S.ATTACK:
			var tm := _move_times()
			return _phase_pose(move.get("anim", "slash"), state_time, tm.x, tm.y, tm.z)
		S.POWER:
			return _phase_pose(power_def.get("anim", "cast"), state_time,
				power_def.get("startup", 0.2), power_def.get("active", 0.1), power_def.get("recovery", 0.3))
	return Poses.get_pose("idle")


func _phase_pose(anim: String, t: float, startup: float, active: float, recovery: float) -> Dictionary:
	var base := Poses.get_pose("idle") if is_grounded() else Poses.get_pose("air")
	var w := Poses.get_pose(anim + "_w")
	var s := Poses.get_pose(anim + "_s")
	if t < startup:
		return Poses.blend(base, w, t / maxf(0.01, startup))
	if t < startup + active:
		return Poses.blend(w, s, minf(1.0, (t - startup) / maxf(0.01, active * 0.5)))
	return Poses.blend(s, base, (t - startup - active) / maxf(0.01, recovery))


func _draw() -> void:
	# shadow (the 3D stage casts real shadows instead)
	if not render_3d:
		_draw_shadow()
	_draw_overlays()


func _draw_shadow() -> void:
	var sh_scale := clampf(1.0 - (ground_y - position.y) / 600.0, 0.3, 1.0)
	draw_set_transform(Vector2(0, ground_y - position.y), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 70.0 * sh_scale, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)


func _draw_overlays() -> void:
	var charged := state == S.POWER or energy >= MAX_ENERGY * 0.999 or (state == S.ATTACK and move_kind == "heavy") \
		or not statuses.is_empty()
	if has_status("clear_sight"):
		var pulse := 0.5 + 0.5 * sin(clock * 6.0)
		draw_arc(Vector2(0, -150), 150.0 + pulse * 12.0, 0, TAU, 48, Color(color, 0.35 + 0.25 * pulse), 4.0)
	if has_status("gravity") and not has_status("anchored"):
		var src_col := pull_source.color if pull_source else Color(0.7, 0.4, 1.0)
		draw_set_transform(Vector2(0, ground_y - position.y), 0.0, Vector2(1.0, 0.25))
		for i in 3:
			var r := 60.0 + fmod(clock * 120.0 + i * 40.0, 120.0)
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(src_col, 0.6 * (1.0 - (r - 60.0) / 120.0)), 5.0)
		draw_set_transform(Vector2.ZERO)
	if has_status("anchored"):
		for i in 5:
			var x := -60.0 + i * 30.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 14, ground_y - position.y), Vector2(x - 4, ground_y - position.y - 26 - (i % 2) * 14),
				Vector2(x + 12, ground_y - position.y)]), Color("6b5a48"))
	if has_status("purified"):
		var pu := 0.5 + 0.5 * sin(clock * 4.0)
		draw_circle(Vector2(0, -150), 135.0 + pu * 10.0, Color(1, 1, 1, 0.06 + 0.04 * pu))
		draw_arc(Vector2(0, -150), 140.0 + pu * 10.0, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	if has_status("cursed"):
		# a ring of dark chain links around the waist
		draw_set_transform(Vector2(0, -150), 0.0, Vector2(1.0, 0.35))
		for i in 12:
			var a := clock * 1.5 + i * TAU / 12.0
			draw_arc(Vector2(cos(a), sin(a)) * 95.0, 12.0, 0, TAU, 10, Color(0.15, 0.35, 0.12, 0.9), 4.0)
		draw_set_transform(Vector2.ZERO)
	var local_trail := PackedVector2Array()
	for wp in _trail:
		local_trail.append(wp - position)
	if render_3d:
		pass   # the 3D puppet draws the body (3D weapon trails come with the real models)
	elif costume.is_empty():
		FighterPainter.paint(self, current_pose(), facing, color, weapon, element, clock, flash, charged)
	else:
		FighterArt.paint(self, current_pose(), facing, color, weapon, element, clock, flash, charged, costume, sec, local_trail)
	if has_status("poison"):
		# green drips rising off the body
		for i in 6:
			var ph := fmod(clock * 0.9 + i * 0.37, 1.0)
			var px := -40.0 + fmod(i * 23.0, 80.0)
			draw_circle(Vector2(px, -60.0 - ph * 200.0), 7.0 * (1.0 - ph) + 2.0, Color(0.45, 1.0, 0.35, 0.7 * (1.0 - ph)))
	if invuln > 0.0 and state == S.POWER and power_def.get("type", "") == "dash":
		# lightning-fast afterimage streaks behind a dash
		for k in 4:
			var x := -facing * (30.0 + k * 34.0)
			draw_line(Vector2(x, -250 + k * 12), Vector2(x, -30), Color(color, 0.35 - k * 0.07), 10.0 - k * 2.0)
