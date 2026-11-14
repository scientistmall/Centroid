class_name ArenaLife
extends Node3D
## The living layer of an arena, in front of its painted backdrop: falling ash, rising
## embers, fireflies, magic motes, mist banks drifting along the ground, firelight and
## crystal light that flicker on the fighters, floating rocks, and the broken pass's
## violet lightning. The world has no sun (the eclipse), so these lights are what
## light the fight.

const CONF := {
	"training_ground": {"ash": 70, "embers": 60, "mist": Color(0.5, 0.46, 0.48), "warm": [Vector3(-7, 1.6, -4), Vector3(7, 1.6, -4)]},
	"silent_forest": {"ash": 0, "fireflies": 45, "mist": Color(0.55, 0.68, 0.72), "cold": [Vector3(0, 3.0, -6)], "cold_col": Color(0.45, 0.8, 0.9)},
	"broken_pass": {"ash": 90, "embers": 20, "mist": Color(0.5, 0.42, 0.6), "rocks": 9, "lightning": true, "warm": [Vector3(-8, 1.0, -6)]},
	"underground_sanctuary": {"ash": 0, "motes": Color(0.4, 1.0, 0.6), "mist": Color(0.35, 0.6, 0.5), "cold": [Vector3(-6, 2.5, -4), Vector3(6, 2.5, -4)], "cold_col": Color(0.3, 1.0, 0.55), "warm": [Vector3(0, 1.2, -8)]},
	"solar_altar": {"ash": 40, "motes": Color(1.0, 0.82, 0.4), "mist": Color(0.5, 0.48, 0.62), "warm": [Vector3(-6, 1.4, -5), Vector3(6, 1.4, -5)], "cold": [Vector3(0, 4.0, -10)], "cold_col": Color(1.0, 0.85, 0.5)},
}

var backdrop: ShaderMaterial
var _warm: Array[OmniLight3D] = []
var _cold: Array[OmniLight3D] = []
var _t := 0.0
var _next_bolt := 4.0
var _flash := 0.0
var _flash_light: OmniLight3D
var _rocks: Array[Node3D] = []


static func make(id: String, root: Node3D, bd: ShaderMaterial) -> ArenaLife:
	var life := ArenaLife.new()
	life.backdrop = bd
	root.add_child(life)
	life._build(CONF.get(id, CONF["training_ground"]))
	return life


func _build(c: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if int(c.get("ash", 0)) > 0:
		var a := _cloud(int(c["ash"]), 9.0, Vector3(0, 7.5, -4), Vector3(16, 1.5, 7), Color(0.55, 0.52, 0.55, 0.7), 0.05, false)
		a.gravity = Vector3(0.25, -0.35, 0)
		a.initial_velocity_min = 0.1
		a.initial_velocity_max = 0.4
	if int(c.get("embers", 0)) > 0:
		var e := _cloud(int(c["embers"]), 5.0, Vector3(0, 0.3, -5), Vector3(16, 0.5, 5), Color(3.0, 0.9, 0.25, 1.0), 0.045, true)
		e.gravity = Vector3(0.15, 0.55, 0)
		e.initial_velocity_min = 0.2
		e.initial_velocity_max = 0.7
	if int(c.get("fireflies", 0)) > 0:
		var f := _cloud(int(c["fireflies"]), 6.0, Vector3(0, 1.8, -5), Vector3(15, 1.6, 6), Color(1.6, 2.2, 0.8, 1.0), 0.06, true)
		f.gravity = Vector3.ZERO
		f.initial_velocity_min = 0.1
		f.initial_velocity_max = 0.35
		f.spread = 180.0
		_pulse_ramp(f, Color(1.6, 2.2, 0.8))
	if c.has("motes"):
		var mc: Color = c["motes"]
		var m := _cloud(50, 7.0, Vector3(0, 0.5, -5), Vector3(15, 1.0, 6), Color(mc.r * 2.0, mc.g * 2.0, mc.b * 2.0, 1.0), 0.05, true)
		m.gravity = Vector3(0, 0.3, 0)
		m.initial_velocity_min = 0.05
		m.initial_velocity_max = 0.2
		_pulse_ramp(m, Color(mc.r * 2.0, mc.g * 2.0, mc.b * 2.0))
	# mist banks along the ground, behind and in front of the fighters
	var mcol: Color = c.get("mist", Color(0.55, 0.6, 0.7))
	for i in 7:
		var mm := Vfx3D.mat(Vfx3D.MIST_SHADER, {"color": mcol, "alpha": 0.2 if i < 5 else 0.12, "seed": rng.randf() * 9.0})
		var z := rng.randf_range(-14.0, -3.0) if i < 5 else rng.randf_range(1.0, 2.5)
		var q := Vfx3D.quad(Vector2(rng.randf_range(7, 11), rng.randf_range(1.6, 2.6)), mm, Vector3(rng.randf_range(-12, 12), 0.6, z), self)
		var tw := q.create_tween().set_loops()
		var dx := rng.randf_range(2.0, 4.0)
		tw.tween_property(q, "position:x", q.position.x + dx, rng.randf_range(9.0, 14.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(q, "position:x", q.position.x, rng.randf_range(9.0, 14.0)).set_trans(Tween.TRANS_SINE)
	# firelight and crystal light on the fighters
	for p in c.get("warm", []):
		_warm.append(_light(p, Color(1.0, 0.55, 0.22), 1.6, 12.0))
	for p in c.get("cold", []):
		_cold.append(_light(p, c.get("cold_col", Color(0.5, 0.8, 1.0)), 1.3, 14.0))
	# floating rocks in the middle distance
	for i in int(c.get("rocks", 0)):
		var rk := Vfx3D.rock_mesh(rng.randf_range(0.12, 0.35), Color(0.24, 0.2, 0.26))
		rk.position = Vector3(rng.randf_range(-13, 13), rng.randf_range(2.5, 6.5), rng.randf_range(-14, -6))
		rk.set_meta("y0", rk.position.y)
		rk.set_meta("ph", rng.randf() * TAU)
		add_child(rk)
		_rocks.append(rk)
	if c.get("lightning", false):
		_flash_light = _light(Vector3(0, 12, -14), Color(0.7, 0.55, 1.0), 0.0, 60.0)
		_next_bolt = rng.randf_range(2.5, 5.0)


func _light(p: Vector3, col: Color, energy: float, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.set_meta("e0", energy)
	add_child(l)
	return l


## A slow, endless particle field (`add` = glowing, otherwise soft and dark).
func _cloud(amount: int, life: float, at: Vector3, ext: Vector3, col: Color, size: float, add: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Vfx3D.soft()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(col, 0.0), col, col, Color(col, 0.0)])
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true
	return p


## Fade in and out a few times over a particle's life (fireflies, motes).
func _pulse_ramp(p: CPUParticles3D, c: Color) -> void:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in 9:
		offs.append(i / 8.0)
		cols.append(Color(c, 0.0 if i % 2 == 0 else 1.0))
	g.offsets = offs
	g.colors = cols
	p.color_ramp = g


func _process(delta: float) -> void:
	_t += delta
	for i in _warm.size():
		var l := _warm[i]
		var f := 0.75 + 0.18 * sin(_t * 13.0 + i * 2.1) + 0.12 * sin(_t * 23.0 + i) + 0.08 * sin(_t * 5.3 + i * 4.0)
		l.light_energy = float(l.get_meta("e0")) * f
	for i in _cold.size():
		var l2 := _cold[i]
		l2.light_energy = float(l2.get_meta("e0")) * (0.8 + 0.25 * sin(_t * 1.5 + i * 1.7))
	for rk in _rocks:
		rk.position.y = float(rk.get_meta("y0")) + 0.25 * sin(_t * 0.8 + float(rk.get_meta("ph")))
		rk.rotation.z += delta * 0.2
		rk.rotation.x += delta * 0.13
	if _flash_light:
		_next_bolt -= delta
		if _next_bolt <= 0.0:
			_next_bolt = randf_range(4.0, 9.0)
			_flash = 1.0
		# a double flicker, then a fading glow
		_flash = maxf(0.0, _flash - delta * 2.6)
		var k := _flash * (0.6 + 0.4 * sin(_flash * 40.0))
		_flash_light.light_energy = 3.0 * k
		if backdrop:
			backdrop.set_shader_parameter("flash", k * 0.7)
