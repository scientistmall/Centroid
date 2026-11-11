class_name Fighter
extends Node2D
## One fighter: movement, combo attacks, blocking, powers, hit reactions.
## Driven by a controller (player or AI) that returns an input Dictionary:
##   move: float (-1..1), jump/light/heavy/power_1/power_2: bool (just pressed),
##   block: bool (held)

signal hp_changed(f: Fighter)
signal energy_changed(f: Fighter)
signal knocked_out(f: Fighter)
signal got_hit(f: Fighter, heavy: bool)
signal power_used(f: Fighter, power_name: String)

enum S { IDLE, WALK, AIR, ATTACK, BLOCK, BLOCKSTUN, HURT, KO, POWER, WIN, FROZEN }

const GRAVITY := 3400.0
const MAX_ENERGY := 100.0
const BODY_HALF_W := 40.0
const BODY_H := 285.0
const PASSIVE_ENERGY := 2.5      # per second
const PUSH_FRICTION := 2600.0

var ground_y := 880.0
var stage_left := 140.0
var stage_right := 1780.0

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
var power_fired := false
var air_attack_used := false
var _last_pose: Dictionary = {}
var statuses: Dictionary = {}   # status name -> seconds left (veil, clear_sight, ...)
var side := 0                   # 0 = player side, 1 = enemy side
var pull_source: Fighter        # who is pulling us (gravity status)
var shots_fired := 0
var pull_speed := 380.0


func setup(fighter_data: Dictionary) -> void:
	data = fighter_data
	char_id = data.get("id", "")
	display_name = data.get("name", char_id.to_upper())
	color = Color(data.get("color", "#ffffff"))
	element = data.get("element", "")
	weapon = data.get("weapon", "sword")
	max_hp = float(data.get("max_hp", 1000))
	walk_speed = float(data.get("walk_speed", 430))
	jump_vel = float(data.get("jump_velocity", 1300))
	powers = data.get("powers", [])
	reset_for_round()


func reset_for_round() -> void:
	hp = max_hp
	energy = float(data.get("start_energy", 20))
	vel = Vector2.ZERO
	stun_time = 0.0
	invuln = 0.0
	flash = 0.0
	clear_statuses()
	move = {}
	queued = ""
	set_state(S.FROZEN)
	hp_changed.emit(self)
	energy_changed.emit(self)


func set_state(s: S) -> void:
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
	var before := energy
	energy = clampf(energy + amount, 0.0, MAX_ENERGY)
	if not is_equal_approx(before, energy):
		energy_changed.emit(self)


# ------------------------------------------------------------------ update

func _physics_process(delta: float) -> void:
	clock += delta
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
	if state not in [S.FROZEN, S.KO, S.WIN]:
		add_energy(PASSIVE_ENERGY * delta)

	inp = {}
	if controller and state not in [S.FROZEN, S.KO, S.WIN]:
		inp = controller.get_input(self, delta)

	match state:
		S.IDLE, S.WALK: _ground_control()
		S.AIR: _air_control()
		S.ATTACK: _attack_update(delta)
		S.BLOCK: _block_update()
		S.BLOCKSTUN, S.HURT: _stun_update(delta)
		S.POWER: _power_update(delta)
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
	var target_alpha := 0.16 if is_veiled() else 1.0
	modulate.a = move_toward(modulate.a, target_alpha, delta * 4.0)
	queue_redraw()


# ------------------------------------------------------------------ statuses

func has_status(n: String) -> bool:
	return statuses.has(n)


func add_status(n: String, seconds: float) -> void:
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


func _ground_control() -> void:
	_face_opponent()
	air_attack_used = false
	if inp.get("block", false):
		vel.x = 0.0
		set_state(S.BLOCK)
		return
	if inp.get("power_1", false) and _try_power(0):
		return
	if inp.get("power_2", false) and _try_power(1):
		return
	if inp.get("light", false):
		_start_attack("light", 0)
		return
	if inp.get("heavy", false):
		_start_attack("heavy", 0)
		return
	var mv: float = inp.get("move", 0.0)
	if inp.get("jump", false):
		vel.y = -jump_vel * (0.6 if has_status("gravity") else 1.0)
		vel.x = mv * walk_speed * 0.95
		set_state(S.AIR)
		return
	var backward: bool = signf(mv) == -facing
	vel.x = mv * walk_speed * (0.72 if backward else 1.0)
	var want := S.WALK if absf(mv) > 0.1 else S.IDLE
	if state != want:
		state = want


func _air_control() -> void:
	if not air_attack_used and (inp.get("light", false) or inp.get("heavy", false)):
		air_attack_used = true
		var m: Dictionary = data.get("moves", {}).get("air", {})
		if not m.is_empty():
			move = m
			move_kind = "air"
			move_hit = false
			queued = ""
			set_state(S.ATTACK)


func _block_update() -> void:
	_face_opponent()
	vel.x = 0.0
	# Powers can be fired straight out of a block (e.g. Stone Bulwark).
	if inp.get("power_1", false) and _try_power(0):
		return
	if inp.get("power_2", false) and _try_power(1):
		return
	if not inp.get("block", false):
		set_state(S.IDLE)


func _stun_update(delta: float) -> void:
	stun_time -= delta
	if stun_time <= 0.0 and is_grounded():
		set_state(S.IDLE)


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

func _chain(kind: String) -> Array:
	return data.get("moves", {}).get(kind, [])


func _start_attack(kind: String, idx: int) -> void:
	var chain := _chain(kind)
	if idx >= chain.size():
		return
	move = chain[idx]
	move_kind = kind
	chain_index = idx
	move_hit = false
	queued = ""
	_face_opponent()
	set_state(S.ATTACK)


func _move_times() -> Vector3:
	return Vector3(move.get("startup", 0.1), move.get("active", 0.08), move.get("recovery", 0.2))


func _attack_update(_delta: float) -> void:
	var tm := _move_times()
	var t := state_time
	# buffer the next press
	if inp.get("light", false):
		queued = "light"
	elif inp.get("heavy", false):
		queued = "heavy"
	if inp.get("block", false) and t >= tm.x + tm.y and move_kind != "air":
		set_state(S.BLOCK)
		return
	if move_kind != "air" and is_grounded():
		if t < tm.x + tm.y:
			vel.x = facing * float(move.get("step", 0.0)) / maxf(0.01, tm.x + tm.y)
		else:
			vel.x = 0.0
	if t >= tm.x and t < tm.x + tm.y and not move_hit:
		_check_melee_hit()
	if t >= tm.x + tm.y and queued != "" and move_kind != "air":
		# cancel recovery into the next hit of a chain
		if queued == move_kind and chain_index + 1 < _chain(move_kind).size():
			_start_attack(move_kind, chain_index + 1)
			return
		if queued == "heavy" and move_kind == "light":
			_start_attack("heavy", 0)
			return
	if t >= tm.x + tm.y + tm.z:
		set_state(S.IDLE if is_grounded() else S.AIR)


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

func _try_power(i: int) -> bool:
	if i >= powers.size():
		return false
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
	set_state(S.POWER)
	power_used.emit(self, p.get("name", "Power"))
	return true


func _power_update(_delta: float) -> void:
	var startup: float = power_def.get("startup", 0.2)
	var active: float = power_def.get("active", 0.1)
	var recovery: float = power_def.get("recovery", 0.3)
	var t := state_time
	var type: String = power_def.get("type", "projectile")
	match type:
		"projectile":
			var count := int(power_def.get("count", 1))
			var interval: float = power_def.get("interval", 0.15)
			while shots_fired < count and t >= startup + shots_fired * interval:
				_spawn_projectile(shots_fired, count)
				shots_fired += 1
		"pull":
			if t >= startup and not power_fired:
				power_fired = true
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
				add_status("anchored", power_def.get("duration", 3.0))
				_spawn_wall()
		"dash":
			if t >= startup and t < startup + active:
				invuln = 0.05
				vel.x = facing * float(power_def.get("speed", 2200))
				if not move_hit and opponent and _dash_rect().intersects(opponent.hurtbox()):
					move_hit = true
					var res := opponent.receive_hit(self, power_def)
					if res != "miss":
						hitstop = 0.08
						_spawn_spark(opponent.position + Vector2(0, -170), res == "block", true)
			elif t >= startup + active:
				vel.x = 0.0
				_resolve_overlap()
		"buff":
			if t >= startup and not power_fired:
				power_fired = true
				var status: String = power_def.get("status", "")
				if status == "veil" and opponent and opponent.has_status("clear_sight"):
					pass  # seen through — the veil fizzles
				else:
					add_status(status, power_def.get("duration", 3.0))
				if status == "clear_sight":
					dispel_enemy_illusions()
				_spawn_burst(power_def.get("radius", 160.0))
		"summon":
			if t >= startup and not power_fired:
				power_fired = true
				if not (opponent and opponent.has_status("clear_sight")):
					_spawn_clone()
				_spawn_burst(120.0)
		"burst":
			if t >= startup and not power_fired:
				power_fired = true
				var r: float = power_def.get("radius", 250.0)
				_spawn_burst(r)
				if opponent and absf(opponent.position.x - position.x) <= r and absf(opponent.position.y - position.y) < 260:
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
	var s := HitSpark.new()
	s.position = at
	s.color = Color(0.8, 0.85, 1.0) if blocked else color
	s.big = heavy
	effects_parent.add_child(s)


# ------------------------------------------------------------------ damage

## Returns "hit", "block" or "miss".
func receive_hit(attacker: Fighter, m: Dictionary) -> String:
	if state == S.KO or invuln > 0.0 or state == S.FROZEN:
		return "miss"
	var dmg: float = float(m.get("damage", 40.0)) * attacker.damage_mult()
	var stun: float = m.get("stun", 0.3)
	var knock: float = m.get("knock", 180.0)
	if has_status("anchored"):
		knock = 0.0
	var away := 1.0 if position.x >= attacker.position.x else -1.0
	var from_front := int(signf(attacker.position.x - position.x)) == facing or is_equal_approx(attacker.position.x, position.x)
	if state in [S.BLOCK, S.BLOCKSTUN] and from_front and not m.get("unblockable", false):
		hp = maxf(1.0, hp - dmg * 0.12)
		stun_time = stun * 0.55
		vel.x = away * knock * 0.7
		add_energy(4.0)
		attacker.add_energy(3.0)
		set_state(S.BLOCKSTUN)
		hp_changed.emit(self)
		return "block"
	hp = maxf(0.0, hp - dmg)
	flash = 1.0
	add_energy(5.0)
	attacker.add_energy(8.0)
	hp_changed.emit(self)
	var heavy := dmg >= 90.0
	got_hit.emit(self, heavy)
	if hp <= 0.0:
		set_state(S.KO)
		vel = Vector2(away * 520.0, -780.0)
		knocked_out.emit(self)
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
	# shadow
	var sh_scale := clampf(1.0 - (ground_y - position.y) / 600.0, 0.3, 1.0)
	draw_set_transform(Vector2(0, ground_y - position.y), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 70.0 * sh_scale, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
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
	FighterPainter.paint(self, current_pose(), facing, color, weapon, element, clock, flash, charged)
	if invuln > 0.0 and state == S.POWER:
		draw_rect(Rect2(-60, -280, 120, 280), Color(color.r, color.g, color.b, 0.12))
