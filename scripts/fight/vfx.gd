class_name Vfx
extends RefCounted
## Particle effects library (CPU particles so it runs on every Android GPU).
## Soft round particles with additive blending give a glowing anime look.

static var _soft: Texture2D
static var _add_mat: CanvasItemMaterial


static func soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 32
		t.height = 32
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_soft = t
	return _soft


static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


static func _ramp(col: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, col.lightened(0.5))
	g.set_color(1, Color(col, 0.0))
	return g


static func _base(amount: int, lifetime: float, col: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.texture = soft_texture()
	p.material = additive()
	p.color_ramp = _ramp(col)
	p.local_coords = false
	return p


## One-shot burst. kind: sparks | embers | dust | mist | motes | drips
static func burst(parent: Node, pos: Vector2, col: Color, kind: String = "sparks", scale: float = 1.0) -> void:
	if parent == null:
		return
	var p: CPUParticles2D
	match kind:
		"embers":
			p = _base(int(22 * scale), 0.9, col)
			p.direction = Vector2(0, -1)
			p.spread = 70.0
			p.initial_velocity_min = 90.0 * scale
			p.initial_velocity_max = 260.0 * scale
			p.gravity = Vector2(0, -120)
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.7
		"dust":
			p = _base(int(18 * scale), 0.8, Color(0.6, 0.52, 0.45))
			p.material = null
			p.direction = Vector2(0, -1)
			p.spread = 80.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 220.0 * scale
			p.gravity = Vector2(0, 250)
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
		"mist":
			p = _base(int(14 * scale), 1.1, Color(0.8, 0.85, 0.95, 0.6))
			p.spread = 180.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 120.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.6
		"motes":
			p = _base(int(16 * scale), 1.0, col)
			p.spread = 180.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 140.0
			p.gravity = Vector2(0, -60)
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.5
		"drips":
			p = _base(int(12 * scale), 0.7, col)
			p.spread = 50.0
			p.direction = Vector2(0, -1)
			p.initial_velocity_min = 80.0
			p.initial_velocity_max = 200.0
			p.gravity = Vector2(0, 700)
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.5
		_:  # sparks
			p = _base(int(26 * scale), 0.38, col)
			p.spread = 180.0
			p.initial_velocity_min = 260.0 * scale
			p.initial_velocity_max = 720.0 * scale
			p.gravity = Vector2(0, 900)
			p.damping_min = 200.0
			p.damping_max = 400.0
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.45
	p.one_shot = true
	p.explosiveness = 0.95
	p.position = pos
	p.z_index = 6
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A continuous emitter for a charged element (attached to a fighter).
static func element_emitter(element: String, col: Color) -> CPUParticles2D:
	var p: CPUParticles2D
	match element:
		"lightning":
			p = _base(18, 0.25, col.lightened(0.4))
			p.spread = 180.0
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 320.0
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.3
		"black_flame":
			p = _base(26, 0.7, col)
			p.direction = Vector2(0, -1)
			p.spread = 25.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 160.0
			p.gravity = Vector2(0, -160)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.8
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 26.0
		"poison":
			p = _base(10, 0.8, col)
			p.direction = Vector2(0, 1)
			p.gravity = Vector2(0, 300)
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.4
		_:
			p = _base(12, 0.8, col)
			p.spread = 180.0
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 80.0
			p.gravity = Vector2(0, -40)
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.5
	p.emitting = false
	return p
