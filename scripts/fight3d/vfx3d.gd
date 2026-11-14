class_name Vfx3D
extends RefCounted
## 3D power effects in the fight's Stage3D world (lightning, black flame, wind, mist, stone,
## gravity, moonlight, poison). Gameplay stays in the 2D logic; these are the visuals, spawned at
## the same moments and positions (2D logic px -> world via Stage3D.to_world). The camera looks
## straight down -Z, so effect quads live in the XY plane facing it.

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.0;
uniform float alpha = 1.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - r, 0.0, 1.0), 2.8);
	ALBEDO = color.rgb * energy * 0.5 * a * alpha;
	ALPHA = a * alpha;
}
"""

const BOLT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float energy = 5.0;
uniform float alpha = 1.0;
uniform float whiten = 0.85;
void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;
	float core = pow(clamp(1.0 - d, 0.0, 1.0), 4.0);
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 1.3) * 0.45;
	vec3 c = mix(color.rgb, vec3(1.0), core * whiten);
	ALBEDO = c * energy * (core + glow) * alpha;
	ALPHA = (core + glow) * alpha;
}
"""

const FIRE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 core_col : source_color = vec3(0.02, 0.0, 0.03);
uniform vec3 edge_col : source_color = vec3(1.0, 0.22, 0.04);
uniform float edge_energy = 4.0;
uniform float speed = 1.6;
uniform float seed = 0.0;
uniform float alpha = 1.0;
uniform float core_from = 0.38;
void fragment() {
	float h = 1.0 - UV.y;
	float x = abs(UV.x - 0.5) * 2.0;
	float n1 = texture(noise_tex, vec2(UV.x * 1.3 + seed, UV.y * 0.9 + TIME * speed)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 2.7 - seed * 1.3, UV.y * 1.8 + TIME * speed * 1.6)).r;
	float n = n1 * 0.65 + n2 * 0.35;
	float shape = (1.0 - h) * 1.2 - x * x * 0.95 + (n - 0.5) * 1.0;
	float m = smoothstep(0.05, 0.32, shape);
	float core = smoothstep(core_from, core_from + 0.3, shape);
	ALBEDO = mix(edge_col * edge_energy, core_col, core);
	ALPHA = m * alpha;
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.0;
uniform float radius = 0.5;
uniform float width = 0.08;
uniform float alpha = 1.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(width, 0.0, abs(d - radius));
	ALBEDO = color.rgb * energy * a * alpha;
	ALPHA = a * alpha;
}
"""

const DOME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 3.0;
uniform float alpha = 1.0;
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	ALBEDO = color.rgb * energy * f * alpha;
	ALPHA = f * alpha;
}
"""

const DISTORT_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform float strength = 0.04;
uniform float alpha = 1.0;
void fragment() {
	float f = 1.0 - abs(dot(NORMAL, VIEW));
	vec2 off = NORMAL.xy * strength * (1.0 - f) * alpha;
	vec3 c = texture(screen_tex, SCREEN_UV - off).rgb;
	vec3 dark = c * mix(1.0, 0.35, (1.0 - f) * alpha);
	ALBEDO = mix(dark, tint.rgb * 2.5, pow(f, 3.0) * 0.8 * alpha);
}
"""

const MIST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 color : source_color = vec4(0.75, 0.8, 0.88, 1.0);
uniform float alpha = 0.6;
uniform float seed = 0.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float n = texture(noise_tex, UV * 0.8 + vec2(TIME * 0.05 + seed, seed * 0.3)).r;
	float a = smoothstep(1.0, 0.2, r) * smoothstep(0.25, 0.75, n);
	ALBEDO = color.rgb;
	ALPHA = a * alpha;
}
"""

static var _shaders: Dictionary = {}
static var _noise: NoiseTexture2D
static var _soft: GradientTexture2D


# ------------------------------------------------------------------------- basics

## Marks left on the ground by powers (scorch, cracks, moon sigil, venom pool, lightning burn).
## Drawn on a quad lying on the floor; `glow` fades faster than the mark itself.
const DECAL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform int mode = 0;
uniform float alpha = 1.0;
uniform float glow = 1.0;
uniform float seed = 0.0;
uniform sampler2D noise_tex : repeat_enable;
float hash(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }
float rays(vec2 p, float r, float ang, int count, float width, float n) {
	float v = 0.0;
	for (int i = 0; i < count; i++) {
		float aa = hash(float(i)) * 6.2831;
		float len = 0.55 + 0.45 * hash(float(i) + 17.0);
		float c = cos(ang - aa);
		float d = c > 0.0 ? abs(sin(ang - aa)) * r : 1.0;
		float w = width * (1.0 - r / len);
		v = max(v, (1.0 - smoothstep(0.0, max(w, 0.0001), d + (n - 0.5) * 0.04)) * step(r, len));
	}
	return v;
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float n = texture(noise_tex, UV * 1.6 + vec2(seed * 0.37, seed * 0.11)).r;
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (mode == 0) {            // scorch with embers
		float edge = 1.0 - smoothstep(0.45 + n * 0.35, 0.95, r);
		a = edge * 0.88;
		float ember = smoothstep(0.58, 0.78, n) * edge * (1.0 - smoothstep(0.15, 0.85, r));
		col = vec3(0.025, 0.018, 0.02) + color.rgb * ember * 3.0 * glow;
	} else if (mode == 1) {     // stone cracks
		float k = rays(p, r, ang, 9, 0.06, n);
		float pit = 1.0 - smoothstep(0.08, 0.28 + n * 0.1, r);
		a = max(k, pit * 0.8) * 0.9;
		col = mix(vec3(0.06, 0.05, 0.04), color.rgb * 2.2, glow * k * 0.7);
	} else if (mode == 2) {     // moonlight sigil
		float ring1 = 1.0 - smoothstep(0.0, 0.035, abs(r - 0.88));
		float ring2 = 1.0 - smoothstep(0.0, 0.02, abs(r - 0.7));
		float c1 = 1.0 - smoothstep(0.38, 0.41, r);
		float c2 = 1.0 - smoothstep(0.30, 0.33, length(p - vec2(0.15, 0.07)));
		float cres = clamp(c1 - c2, 0.0, 1.0);
		float band = step(0.72, r) * step(r, 0.84);
		float ticks = band * step(0.75, fract(ang / 6.2831 * 24.0));
		a = max(max(ring1, ring2), max(cres, ticks)) * glow;
		col = color.rgb * 1.5;
	} else if (mode == 3) {     // venom pool
		float blob = 1.0 - smoothstep(0.42 + n * 0.3, 0.7 + n * 0.25, r);
		float shine = smoothstep(0.6, 0.85, texture(noise_tex, UV * 3.0 + TIME * 0.05).r);
		a = blob * 0.85;
		col = mix(color.rgb * 0.25, color.rgb * 1.8, shine * 0.6 + 0.25 * glow);
	} else {                    // lightning burn
		float edge = 1.0 - smoothstep(0.25 + n * 0.25, 0.6, r);
		float k = rays(p, r, ang, 11, 0.035, n);
		a = max(edge * 0.7, k);
		col = mix(vec3(0.02, 0.025, 0.04), color.rgb * 3.0, glow * k);
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * alpha;
}
"""


static func stage() -> Stage3D:
	return Stage3D.current


static func on() -> bool:
	return Stage3D.current != null and is_instance_valid(Stage3D.current)


static func world(p2d: Vector2, z := 0.25) -> Vector3:
	var w := Stage3D.current.to_world(p2d)
	w.z = z
	return w


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


static func noise() -> NoiseTexture2D:
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.seamless = true
		_noise.width = 256
		_noise.height = 256
		var fn := FastNoiseLite.new()
		fn.frequency = 0.012
		fn.fractal_octaves = 4
		_noise.noise = fn
	return _noise


static func soft() -> GradientTexture2D:
	if _soft == null:
		_soft = GradientTexture2D.new()
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_soft.gradient = g
	return _soft


static func mat(code: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(code)
	for k in params:
		m.set_shader_parameter(k, params[k])
	if code == FIRE_SHADER or code == MIST_SHADER or code == DECAL_SHADER:
		m.set_shader_parameter("noise_tex", noise())
	return m


static func quad(size: Vector2, m: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	(parent if parent else Stage3D.current.world_root).add_child(mi)
	return mi


## Fade a shader "alpha" to 0 over `time` after `delay`, then free the node.
static func fade_free(n: Node3D, m: ShaderMaterial, time: float, delay := 0.0) -> void:
	var t := n.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_method(func(v: float): m.set_shader_parameter("alpha", v), 1.0, 0.0, time)
	t.tween_callback(n.queue_free)


static func flash(pos: Vector3, col: Color, energy := 6.0, rng := 6.0, time := 0.35) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	Stage3D.current.world_root.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_OUT)
	t.tween_callback(l.queue_free)


static func glow(pos: Vector3, size: float, col: Color, energy := 3.0, time := 0.3, grow := 1.4) -> MeshInstance3D:
	var m := mat(GLOW_SHADER, {"color": col, "energy": energy})
	var g := quad(Vector2(size, size), m, pos)
	g.create_tween().tween_property(g, "scale", Vector3.ONE * grow, time).set_ease(Tween.EASE_OUT)
	fade_free(g, m, time)
	return g


static func ring(pos: Vector3, size: float, col: Color, time := 0.45, ground := false) -> void:
	var m := mat(RING_SHADER, {"color": col, "energy": 1.8, "radius": 0.15, "width": 0.05})
	var r := quad(Vector2(size, size), m, pos)
	if ground:
		r.rotation_degrees.x = -90.0
	var t := r.create_tween().set_parallel(true)
	t.tween_method(func(v: float): m.set_shader_parameter("radius", v), 0.15, 0.95, time).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float): m.set_shader_parameter("alpha", v), 1.0, 0.0, time)
	t.chain().tween_callback(r.queue_free)


## One-shot particle burst. `kind`: sparks, embers, dust, motes, drips, leaves, shards.
static func particles(pos: Vector3, col: Color, kind := "sparks", amount := 40, power := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = 0.7
	p.position = pos
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 2.0 * power
	p.initial_velocity_max = 6.0 * power
	p.gravity = Vector3(0, -6.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	var q := QuadMesh.new()
	var psize := 0.1
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	var hot := Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 1.0)
	match kind:
		"embers":
			p.gravity = Vector3(0, 2.0, 0)
			p.lifetime = 1.1
			hot = Color(3.5, 0.8, 0.2)
		"dust":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			p.gravity = Vector3(0, -1.5, 0)
			psize = 0.45
			p.lifetime = 1.2
			p.initial_velocity_max = 3.0 * power
			hot = Color(0.45, 0.38, 0.3, 0.55)
		"motes":
			p.gravity = Vector3(0, 1.2, 0)
			p.lifetime = 1.3
			p.initial_velocity_max = 2.5 * power
		"drips":
			p.gravity = Vector3(0, -12.0, 0)
			psize = 0.07
		"leaves":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			p.gravity = Vector3(0, -1.0, 0)
			p.lifetime = 1.2
			p.angular_velocity_min = -360.0
			p.angular_velocity_max = 360.0
			hot = Color(0.45, 0.85, 0.55, 0.9)
		"shards":
			p.gravity = Vector3(0, -9.0, 0)
			psize = 0.12
	q.size = Vector2(psize, psize)
	var ramp := Gradient.new()
	ramp.set_color(0, hot)
	ramp.set_color(1, Color(hot.r, hot.g, hot.b, 0.0))
	p.color_ramp = ramp
	Stage3D.current.world_root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


# ------------------------------------------------------------------------- lightning

class Bolt extends MeshInstance3D:
	## A jagged lightning bolt from a to b that re-strikes (flickers) and fades.
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var width := 0.09
	var life := 0.35
	var jitter := 0.22
	var branches := 2
	var follow_a: Callable
	var follow_b: Callable
	var _t := 0.0
	var _regen := 0.0
	var _m: ShaderMaterial

	func start(col: Color) -> void:
		_m = Vfx3D.mat(Vfx3D.BOLT_SHADER, {"color": col, "energy": 5.0})
		material_override = _m
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_build()

	func _process(delta: float) -> void:
		_t += delta
		_regen -= delta
		if follow_a.is_valid():
			a = follow_a.call()
		if follow_b.is_valid():
			b = follow_b.call()
		if _regen <= 0.0:
			_regen = 0.045
			_build()
		_m.set_shader_parameter("alpha", clampf(1.0 - (_t - life * 0.6) / (life * 0.4), 0.0, 1.0) * (0.75 + randf() * 0.25))
		if _t >= life:
			queue_free()

	func _build() -> void:
		var am := ArrayMesh.new()
		_strip(am, _path(a, b, jitter, 6), width)
		for i in branches:
			var pts := _path(a, b, jitter, 6)
			var k := randi_range(1, pts.size() - 2)
			var s: Vector3 = pts[k]
			var dir := (b - a).normalized()
			var side := Vector3(-dir.y, dir.x, 0) * randf_range(-1.0, 1.0)
			var e: Vector3 = s + (dir * randf_range(0.2, 0.5) + side * 0.5) * a.distance_to(b) * 0.35
			_strip(am, _path(s, e, jitter * 0.6, 4), width * 0.55)
		mesh = am

	static func _path(p0: Vector3, p1: Vector3, j: float, depth: int) -> Array:
		var pts: Array = [p0, p1]
		var amp := p0.distance_to(p1) * j
		for d in depth:
			var out: Array = [pts[0]]
			for i in range(1, pts.size()):
				var m: Vector3 = (pts[i - 1] + pts[i]) * 0.5
				var dir: Vector3 = (pts[i] - pts[i - 1]).normalized()
				var nrm := Vector3(-dir.y, dir.x, 0.0)
				out.append(m + nrm * randf_range(-amp, amp))
				out.append(pts[i])
			pts = out
			amp *= 0.5
		return pts

	static func _strip(am: ArrayMesh, pts: Array, w: float) -> void:
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in pts.size():
			var p: Vector3 = pts[i]
			var dir: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]) as Vector3).normalized()
			var n := Vector3(-dir.y, dir.x, 0.0) * w * (1.0 - 0.5 * float(i) / pts.size())
			v.append(p - n)
			v.append(p + n)
			uv.append(Vector2(0, float(i) / pts.size()))
			uv.append(Vector2(1, float(i) / pts.size()))
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = uv
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arr)


static func bolt(a: Vector3, b: Vector3, col: Color, life := 0.3, width := 0.09, branches := 2) -> Bolt:
	var bo := Bolt.new()
	bo.a = a
	bo.b = b
	bo.life = life
	bo.width = width
	bo.branches = branches
	Stage3D.current.world_root.add_child(bo)
	bo.start(col)
	return bo


static func strike(at: Vector3, col: Color, power := 1.0) -> void:
	for i in 4:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1), 0).normalized()
		bolt(at, at + dir * randf_range(0.5, 1.1) * power, col, 0.22, 0.05, 1)
	glow(at, 1.6 * power, col, 4.0, 0.25)
	particles(at, col, "sparks", 50, power)
	flash(at, col, 8.0 * power, 7.0, 0.3)


# ------------------------------------------------------------------------- followers

class Follow extends Node3D:
	## Keeps a group of effects on a moving 2D logic object (projectile / fighter).
	var target: Node2D
	var offset := Vector3.ZERO
	var on_end: Callable
	var keep_after := 0.0

	func _process(_d: float) -> void:
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			if on_end.is_valid():
				on_end.call(self)
				on_end = Callable()
			if keep_after <= 0.0:
				queue_free()
			else:
				keep_after -= _d
			return
		position = Vfx3D.world(target.position) + offset


static func follow(target: Node2D, offset := Vector3(0, 0, 0.25)) -> Follow:
	var f := Follow.new()
	f.target = target
	f.offset = offset
	Stage3D.current.world_root.add_child(f)
	f.position = world(target.position) + offset
	return f


static func trail(parent: Node3D, col: Color, kind := "sparks", rate := 60, size := 0.08) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = rate
	p.lifetime = 0.5
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.5 if kind != "dust" else -1.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if kind != "dust" else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	var hot := Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 1.0) if kind != "dust" else Color(0.4, 0.34, 0.28, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, hot)
	ramp.set_color(1, Color(hot.r, hot.g, hot.b, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	return p


# ------------------------------------------------------------------------- projectiles

static func on_projectile(p: Projectile) -> void:
	if not on():
		return
	var col := p.color
	var f := follow(p)
	match p.fx:
		"bolt":
			var core := quad(Vector2(0.7, 0.7), mat(GLOW_SHADER, {"color": col, "energy": 6.0}), Vector3.ZERO, f)
			core.scale = Vector3(1.6, 1.0, 1.0)
			var d := float(p.dir)
			var arcs := Bolt.new()
			arcs.life = 99.0
			arcs.width = 0.05
			arcs.branches = 3
			arcs.follow_a = func(): return f.position + Vector3(-0.45 * d, 0, 0)
			arcs.follow_b = func(): return f.position + Vector3(0.45 * d, randf_range(-0.15, 0.15), 0)
			Stage3D.current.world_root.add_child(arcs)
			arcs.start(col)
			f.tree_exiting.connect(arcs.queue_free)
			trail(f, col, "sparks", 70, 0.07)
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 3.0
			l.omni_range = 4.0
			f.add_child(l)
		"flame_wave":
			for i in 3:
				var fm := mat(FIRE_SHADER, {"edge_col": Color(1.0, 0.16, 0.03), "core_col": Color(0.015, 0.0, 0.02),
					"edge_energy": 3.6, "core_from": 0.16, "seed": randf() * 10.0, "speed": 1.8})
				var fq := quad(Vector2(1.1, 1.4), fm, Vector3((i - 1) * 0.35 * p.dir, 0.05, 0.02 * i), f)
				fq.position.y = -0.2 + 0.7
			trail(f, Color(1.0, 0.3, 0.05), "embers", 50, 0.06)
			var l2 := OmniLight3D.new()
			l2.light_color = Color(1.0, 0.25, 0.05)
			l2.light_energy = 3.5
			l2.omni_range = 4.5
			f.add_child(l2)
		"wind":
			for i in 2:
				var wm := mat(RING_SHADER, {"color": col, "energy": 2.5, "radius": 0.6, "width": 0.12})
				var wq := quad(Vector2(0.9, 0.5), wm, Vector3(-0.25 * i * p.dir, 0, 0), f)
				wq.rotation_degrees.y = 70.0
				wq.create_tween().set_loops().tween_property(wq, "rotation_degrees:x", 360.0, 0.25).from(0.0)
			quad(Vector2(1.6, 0.35), mat(GLOW_SHADER, {"color": col, "energy": 2.5}), Vector3(-0.4 * p.dir, 0, 0), f)
			trail(f, col, "leaves", 30, 0.09)
		"quake":
			f.offset = Vector3(0, 0, 0.3)
			trail(f, col, "dust", 50, 0.5)
			var spikes := Timer.new()
			spikes.wait_time = 0.08
			spikes.autostart = true
			f.add_child(spikes)
			spikes.timeout.connect(func(): if is_instance_valid(p): rock_spike(Vector3(f.position.x, 0, 0.2), 0.5))
		"rock":
			var rk := rock_mesh(0.32, Color(0.33, 0.27, 0.36))
			f.add_child(rk)
			rk.create_tween().set_loops().tween_property(rk, "rotation:z", TAU, 0.5).from(0.0)
			quad(Vector2(0.9, 0.9), mat(GLOW_SHADER, {"color": col, "energy": 2.0}), Vector3(0, 0, -0.05), f)
			trail(f, col, "sparks", 30, 0.06)
		_:
			quad(Vector2(0.8, 0.8), mat(GLOW_SHADER, {"color": col, "energy": 4.0}), Vector3.ZERO, f)
			trail(f, col, "sparks", 40, 0.06)


static func on_projectile_end(p: Projectile, hit: bool) -> void:
	if not on():
		return
	var at := world(p.position)
	match p.fx:
		"bolt":
			strike(at, p.color, 1.2 if hit else 0.8)
			decal(Vector3(at.x, 0, 0.15), 2.2, p.color, "burn", 1.6)
		"flame_wave":
			decal(Vector3(at.x, 0, 0.15), 3.0, Color(1.0, 0.25, 0.05), "scorch", 2.2)
			for i in 4:
				var fm := mat(FIRE_SHADER, {"edge_col": Color(1.0, 0.18, 0.04), "edge_energy": 4.0, "core_from": 0.18, "seed": randf() * 9.0})
				var fq := quad(Vector2(1.2, 1.8), fm, at + Vector3(randf_range(-0.4, 0.4), 0.6, 0.05 * i))
				fade_free(fq, fm, 0.5, 0.1)
			particles(at, Color(1, 0.3, 0.05), "embers", 60, 1.2)
			flash(at, Color(1.0, 0.25, 0.05), 8.0)
		"wind":
			ring(at, 2.2, p.color, 0.35)
			particles(at, p.color, "leaves", 30, 1.0)
		"quake", "rock":
			decal(Vector3(at.x, 0, 0.15), 2.4, p.color, "crack", 2.0)
			particles(at, p.color, "dust", 26, 1.2)
			particles(at, Color(0.5, 0.4, 0.3), "shards", 24, 1.3)
			flash(at, p.color, 3.0)
		_:
			glow(at, 1.4, p.color, 4.0, 0.3)
			particles(at, p.color, "sparks", 40, 1.0)


# ------------------------------------------------------------------------- rocks

static func rock_mesh(r: float, col: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 1.6
	mesh.radial_segments = 7
	mesh.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	m.albedo_texture = noise()
	m.uv1_scale = Vector3(2, 2, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	mi.scale = Vector3(randf_range(0.8, 1.3), randf_range(0.7, 1.1), randf_range(0.8, 1.2))
	return mi


## A jagged rock spike bursting out of the ground and sinking back.
static func rock_spike(at: Vector3, h: float, life := 0.7) -> void:
	var p := PrismMesh.new()
	p.size = Vector3(h * 0.5, h, h * 0.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.29, 0.22)
	m.albedo_texture = noise()
	m.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.material_override = m
	mi.rotation.z = randf_range(-0.35, 0.35)
	mi.position = at + Vector3(0, -h, 0)
	Stage3D.current.world_root.add_child(mi)
	var t := mi.create_tween()
	t.tween_property(mi, "position:y", at.y + h * 0.45, 0.08).set_ease(Tween.EASE_OUT)
	t.tween_interval(life)
	t.tween_property(mi, "position:y", at.y - h, 0.25)
	t.tween_callback(mi.queue_free)


# ------------------------------------------------------------------------- powers

## Visuals for a power at the moment it fires. `f` is the caster.
static func on_power(f: Fighter, pd: Dictionary) -> void:
	if not on():
		return
	var col := f.color
	var type: String = pd.get("type", "")
	var chest := world(f.position + Vector2(0, -150))
	var feet := world(f.position)
	match type:
		"burst":   # Hellfire Burst: a dome of black fire
			var r: float = float(pd.get("radius", 250.0)) / Stage3D.PPM
			var dm := mat(DOME_SHADER, {"color": Color(1.0, 0.2, 0.04), "energy": 2.2})
			var sm := SphereMesh.new()
			sm.radius = 0.4
			sm.height = 0.8
			var dome := MeshInstance3D.new()
			dome.mesh = sm
			dome.material_override = dm
			dome.position = chest
			Stage3D.current.world_root.add_child(dome)
			dome.create_tween().tween_property(dome, "scale", Vector3.ONE * r * 2.6, 0.35).set_ease(Tween.EASE_OUT)
			fade_free(dome, dm, 0.45, 0.1)
			for i in 9:
				var a := TAU * i / 9.0
				var fm := mat(FIRE_SHADER, {"edge_col": Color(1.0, 0.18, 0.03), "edge_energy": 4.0, "core_from": 0.18, "seed": randf() * 9.0, "speed": 2.4})
				var fq := quad(Vector2(1.0, 1.8), fm, feet + Vector3(cos(a) * r * 0.8, 0.85, 0.2 + sin(a) * 0.3))
				fq.scale = Vector3.ONE * 0.2
				fq.create_tween().tween_property(fq, "scale", Vector3.ONE, 0.18)
				fade_free(fq, fm, 0.4, 0.35)
			ring(feet + Vector3(0, 0.05, 0), r * 3.2, Color(1.0, 0.3, 0.05), 0.4, true)
			particles(chest, Color(1, 0.3, 0.05), "embers", 90, 1.8)
			flash(chest, Color(1.0, 0.25, 0.05), 12.0, 9.0, 0.5)
		"dash":    # Thunder Step: a lightning streak along the dash
			var start := chest
			var trail_b := bolt(start, start, col, float(pd.get("active", 0.25)) + 0.25, 0.12, 3)
			trail_b.follow_b = func(): return Vfx3D.world(f.position + Vector2(0, -150)) if is_instance_valid(f) else trail_b.b
			glow(start, 2.0, col, 5.0, 0.3)
			particles(feet, col, "sparks", 50, 1.2)
			flash(start, col, 7.0)
		"buff":
			match String(pd.get("status", "")):
				"purified":   # Mira: moonlight pillar
					var pm := mat(GLOW_SHADER, {"color": Color(1.0, 0.7, 0.88), "energy": 2.4})
					var pillar := quad(Vector2(0.9, 5.0), pm, feet + Vector3(0, 2.3, 0.2))
					pillar.scale = Vector3(0.2, 1, 1)
					pillar.create_tween().tween_property(pillar, "scale", Vector3.ONE, 0.2)
					fade_free(pillar, pm, 0.7, 0.3)
					ring(chest, 3.0, Color(1.0, 0.7, 0.9), 0.6)
					particles(chest, Color(1.0, 0.8, 0.95), "motes", 70, 1.0)
					flash(chest, Color(1.0, 0.75, 0.9), 6.0)
				"clear_sight":   # Tala: a wind ring that blows the illusions away
					ring(chest, 6.0, col, 0.55)
					ring(chest, 3.5, Color(1, 1, 1), 0.4)
					particles(chest, col, "leaves", 60, 2.2)
					glow(world(f.position + Vector2(0, -230)), 0.7, Color(0.6, 1.0, 0.8), 6.0, 0.6)
				"veil":   # Vaska: mist gathers around her
					mist(f, 3.0)
				_:
					ring(chest, 3.0, col, 0.5)
					particles(chest, col, "motes", 40, 1.0)
		"wall":    # Darin: a rampart of rock bursts up
			var x := world(f.position + Vector2(f.facing * 120.0, 0))
			for i in 5:
				rock_spike(Vector3(x.x + randf_range(-0.3, 0.3), 0, 0.15 + randf_range(-0.2, 0.2)),
					randf_range(1.2, 1.7), float(pd.get("duration", 3.0)) - 0.3)
			particles(Vector3(x.x, 0.2, 0.3), Color(0.5, 0.4, 0.3), "dust", 50, 1.5)
			flash(Vector3(x.x, 1.0, 0.4), col, 3.0)
		"pull":    # Mael: gravity well around the opponent
			if f.opponent:
				gravity_well(f.opponent, float(pd.get("duration", 1.4)), col)
		"summon":  # Vaska: the double steps out of a mist burst
			if f.opponent:
				var at := world(Vector2(f.opponent.position.x - f.opponent.facing * 260.0, f.position.y - 140.0))
				for i in 5:
					var mm := mat(MIST_SHADER, {"color": Color(0.7, 0.76, 0.86), "alpha": 0.4, "seed": randf() * 5.0})
					var mq := quad(Vector2(2.2, 2.2), mm, at + Vector3(randf_range(-0.5, 0.5), randf_range(-0.4, 0.6), 0.1 * i))
					mq.create_tween().tween_property(mq, "scale", Vector3.ONE * 1.6, 0.8)
					fade_free(mq, mm, 0.8)
		"lash", "drain", "projectile":
			pass   # drawn by on_lash / on_projectile
	signature(f, pd)


static func on_lash(f: Fighter, from2d: Vector2, to2d: Vector2) -> void:
	if not on():
		return
	var poison := f.element == "poison"
	var col := Color(0.55, 1.0, 0.3) if poison else f.color
	var a := world(from2d)
	var b := world(to2d)
	var wb := bolt(a, b, col, 0.3, 0.08, 0)
	wb.jitter = 0.035
	wb._m.set_shader_parameter("whiten", 0.25)
	wb._m.set_shader_parameter("energy", 3.2)
	glow(b, 0.9, col, 4.0, 0.3)
	if poison:
		particles(b, Color(0.4, 1.0, 0.2), "drips", 30, 0.8)
		decal(Vector3(b.x, 0, 0.15), 2.0, Color(0.4, 1.0, 0.25), "pool", 2.4)
		if f.state == Fighter.S.POWER and String(f.power_def.get("type", "")) == "drain" and f.opponent:
			# energy drained back to Nyra
			var back := bolt(b, world(f.position + Vector2(0, -150)), Color(0.3, 0.9, 0.3), 0.45, 0.05, 2)
			back.jitter = 0.3
			back._m.set_shader_parameter("whiten", 0.4)
	else:
		particles(b, Color(1.0, 0.8, 0.95), "motes", 30, 0.9)


## Mist around a fighter for the veil's duration.
static func mist(f: Fighter, duration: float) -> void:
	var fl := follow(f, Vector3(0, 1.0, 0.3))
	for i in 6:
		var mm := mat(MIST_SHADER, {"color": Color(0.66, 0.72, 0.84), "alpha": 0.32, "seed": randf() * 7.0})
		var mq := quad(Vector2(2.4, 2.4), mm, Vector3(randf_range(-0.7, 0.7), randf_range(-0.6, 0.6), randf_range(-0.2, 0.3)), fl)
		mq.create_tween().set_loops().tween_property(mq, "position:x", mq.position.x + randf_range(-0.4, 0.4), 1.6).set_trans(Tween.TRANS_SINE)
	var t := fl.create_tween()
	t.tween_interval(duration)
	t.tween_callback(fl.queue_free)


static func gravity_well(target: Fighter, duration: float, col: Color) -> void:
	var fl := follow(target, Vector3(0, 0.9, 0.3))
	var sm := SphereMesh.new()
	sm.radius = 0.75
	sm.height = 1.5
	var dm := mat(DISTORT_SHADER, {"tint": col, "strength": 0.05})
	var core := MeshInstance3D.new()
	core.mesh = sm
	core.material_override = dm
	fl.add_child(core)
	core.scale = Vector3.ONE * 0.1
	core.create_tween().tween_property(core, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
	for i in 7:
		var rk := rock_mesh(0.09, Color(0.3, 0.25, 0.32))
		var pivot := Node3D.new()
		fl.add_child(pivot)
		pivot.add_child(rk)
		rk.position = Vector3(randf_range(0.9, 1.3), randf_range(-0.6, 0.6), 0)
		pivot.rotation.y = randf() * TAU
		pivot.create_tween().set_loops().tween_property(pivot, "rotation:y", pivot.rotation.y + TAU, randf_range(0.7, 1.2)).from(pivot.rotation.y)
	ring(fl.position, 4.0, col, 0.5)
	var t := fl.create_tween()
	t.tween_interval(duration)
	t.tween_method(func(v: float): dm.set_shader_parameter("alpha", v), 1.0, 0.0, 0.3)
	t.tween_callback(fl.queue_free)


# ------------------------------------------------------------------------- specials

const DECAL_MODE := {"scorch": 0, "crack": 1, "sigil": 2, "pool": 3, "burn": 4}

## A mark on the floor under world point `at`, lingering `life` seconds.
static func decal(at: Vector3, size: float, col: Color, kind: String, life := 2.0) -> void:
	if not on():
		return
	var m := mat(DECAL_SHADER, {"color": col, "mode": DECAL_MODE.get(kind, 0), "seed": randf() * 20.0})
	var d := quad(Vector2(size, size), m, Vector3(at.x, 0.02, clampf(at.z, 0.0, 0.4)))
	d.rotation_degrees.x = -90.0
	d.rotation_degrees.y = randf() * 360.0
	d.scale = Vector3.ONE * 0.6
	var t := d.create_tween().set_parallel(true)
	t.tween_property(d, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float): m.set_shader_parameter("glow", v), 1.0, 0.0, minf(0.9, life * 0.5))
	t.chain().tween_interval(maxf(0.0, life - 0.9))
	t.chain().tween_method(func(v: float): m.set_shader_parameter("alpha", v), 1.0, 0.0, 0.9)
	t.chain().tween_callback(d.queue_free)


## Charge-up the moment a power starts: an aura behind the caster, energy pulled
## inward from around them, a glow ring on the floor. Lasts until the power is out.
static func charge(f: Fighter, pd: Dictionary) -> void:
	if not on():
		return
	var col := f.color
	var dur := float(pd.get("startup", 0.2)) + float(pd.get("active", 0.1)) + 0.25
	var fl := follow(f, Vector3(0, 1.05, 0.1))
	var am := mat(GLOW_SHADER, {"color": col, "energy": 2.4})
	var aura := quad(Vector2(2.4, 3.4), am, Vector3(0, 0.1, -0.35), fl)
	aura.scale = Vector3(0.5, 0.5, 1.0)
	aura.create_tween().tween_property(aura, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	fade_free(aura, am, 0.3, maxf(0.0, dur - 0.3))
	# energy drawn in from a sphere around the body
	var p := CPUParticles3D.new()
	p.amount = 46
	p.lifetime = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 1.5
	p.gravity = Vector3.ZERO
	p.radial_accel_min = -34.0
	p.radial_accel_max = -26.0
	p.local_coords = true
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 0.0))
	ramp.set_color(1, Color(col.r * 2.2, col.g * 2.2, col.b * 2.2, 1.0))
	p.color_ramp = ramp
	fl.add_child(p)
	p.emitting = true
	ring(world(f.position) + Vector3(0, 0.03, 0.1), 3.4, col, 0.45, true)
	flash(fl.position, col, 5.0, 6.0, dur)
	var t := fl.create_tween()
	t.tween_interval(maxf(0.05, dur - 0.3))
	t.tween_callback(func(): p.emitting = false)
	t.tween_interval(0.35)
	t.tween_callback(fl.queue_free)


## Per-power extras on top of the base effect, so each special has its own signature.
static func signature(f: Fighter, pd: Dictionary) -> void:
	var col := f.color
	var feet := world(f.position)
	var hand := world(f.position + Vector2(f.facing * 70.0, -170.0))
	match String(pd.get("id", "")):
		"arc_bolt":   # forked arcs from the blade to the ground
			for i in 3:
				var g := Vector3(hand.x + f.facing * randf_range(0.4, 1.4), 0.0, randf_range(0.0, 0.35))
				var b := bolt(hand, g, col, 0.22, 0.05, 1)
				b.jitter = 0.25
			decal(feet + Vector3(f.facing * 0.9, 0, 0.15), 2.4, col, "burn", 1.6)
		"thunder_step":
			decal(feet, 2.6, col, "burn", 1.8)
		"black_flame_wave":
			decal(feet + Vector3(f.facing * 0.8, 0, 0.1), 2.6, Color(1.0, 0.25, 0.05), "scorch", 2.2)
		"hellfire_burst":   # a rising column of black fire that mushrooms out
			decal(feet, 5.0, Color(1.0, 0.25, 0.05), "scorch", 2.6)
			var cm := mat(FIRE_SHADER, {"edge_col": Color(1.0, 0.16, 0.03), "core_col": Color(0.015, 0.0, 0.02),
				"edge_energy": 4.0, "core_from": 0.18, "seed": randf() * 9.0, "speed": 3.0})
			var col_q := quad(Vector2(1.6, 4.5), cm, feet + Vector3(0, 2.2, 0.0))
			col_q.scale = Vector3(0.6, 0.1, 1.0)
			col_q.create_tween().tween_property(col_q, "scale", Vector3.ONE, 0.28).set_ease(Tween.EASE_OUT)
			fade_free(col_q, cm, 0.45, 0.35)
			for i in 6:
				var a := TAU * i / 6.0
				var pm := mat(FIRE_SHADER, {"edge_col": Color(1.0, 0.2, 0.04), "core_col": Color(0.02, 0.0, 0.02),
					"edge_energy": 3.2, "core_from": 0.2, "seed": randf() * 9.0, "speed": 2.0})
				var puff := quad(Vector2(1.4, 1.4), pm, feet + Vector3(0, 4.2, 0.05 * i))
				puff.scale = Vector3.ONE * 0.2
				var t := puff.create_tween().set_parallel(true)
				t.tween_property(puff, "position", feet + Vector3(cos(a) * 1.3, 4.3 + sin(a) * 0.5, 0.05 * i), 0.4).set_delay(0.18).set_ease(Tween.EASE_OUT)
				t.tween_property(puff, "scale", Vector3.ONE, 0.4).set_delay(0.18)
				fade_free(puff, pm, 0.5, 0.45)
		"stone_bulwark":
			decal(world(f.position + Vector2(f.facing * 120.0, 0)), 3.0, col, "crack", 3.0)
		"quake_fist", "rising_stones":
			decal(feet + Vector3(f.facing * 0.5, 0, 0.1), 3.0, col, "crack", 2.4)
		"gravity_well":   # debris dragged in toward the target
			if f.opponent:
				var at := world(f.opponent.position + Vector2(0, -120))
				for i in 12:
					var a := randf() * TAU
					var rk := rock_mesh(randf_range(0.05, 0.11), Color(0.3, 0.25, 0.32))
					rk.position = at + Vector3(cos(a) * 2.6, sin(a) * 1.6, 0.2)
					Stage3D.current.world_root.add_child(rk)
					var t := rk.create_tween()
					t.tween_property(rk, "position", at, randf_range(0.35, 0.6)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
					t.tween_callback(rk.queue_free)
				decal(world(f.opponent.position), 3.2, col, "crack", 1.8)
		"purify":
			decal(feet, 3.6, Color(1.0, 0.72, 0.9), "sigil", 2.2)
		"clear_sight", "piercing_gale":
			ring(feet + Vector3(0, 0.03, 0.1), 4.5, col, 0.5, true)
		"veil_of_mist", "mirror_double":
			ring(feet + Vector3(0, 0.03, 0.1), 3.5, Color(0.7, 0.76, 0.86), 0.6, true)
		"venom_lash", "withering_curse":
			pass   # marks where the whip lands (on_lash)


# ------------------------------------------------------------------------- hits

static func on_hit(at2d: Vector2, col: Color, blocked: bool, heavy: bool, element: String) -> void:
	if not on():
		return
	var at := world(at2d, 0.4)
	var c := Color(0.75, 0.85, 1.0) if blocked else col
	glow(at, 0.9 if heavy else 0.55, c, 4.0, 0.16, 1.5)
	particles(at, c, "sparks", 40 if heavy else 22, 1.4 if heavy else 1.0)
	if not blocked:
		match element:
			"lightning": strike(at, col, 0.6 if heavy else 0.4)
			"black_flame": particles(at, col, "embers", 30, 1.0)
			"stone", "gravity": particles(at, Color(0.5, 0.4, 0.3), "dust", 14, 0.8)
			"moonlight": particles(at, Color(1.0, 0.8, 0.95), "motes", 20, 0.8)
			"poison": particles(at, Color(0.4, 1.0, 0.2), "drips", 16, 0.7)
	if heavy:
		ring(at, 1.8, c, 0.25)
		flash(at, c, 4.0, 5.0, 0.2)
