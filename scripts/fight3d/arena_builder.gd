class_name ArenaBuilder
extends RefCounted
## Builds each fight location as a 3D scene from primitive meshes, materials and
## lights (night sky, fog for depth, moonlit rim light, warm practical lights, bloom).

static func mat(col: Color, rough := 0.85, metal := 0.0, emissive := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = energy
	return m


static func noise_mat(col_a: Color, col_b: Color, scale := 0.05, rough := 0.9) -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.frequency = scale
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.seamless = true
	var g := Gradient.new()
	g.set_color(0, col_a)
	g.set_color(1, col_b)
	tex.color_ramp = g
	var nrm := NoiseTexture2D.new()
	nrm.noise = n
	nrm.seamless = true
	nrm.as_normal_map = true
	nrm.bump_strength = 6.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = nrm
	m.roughness = rough
	m.uv1_scale = Vector3(10, 10, 10)
	nrm.bump_strength = 3.0
	return m


static func add_mesh(root: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi


static func box(sx: float, sy: float, sz: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(sx, sy, sz)
	return b


static func cyl(r_top: float, r_bot: float, h: float, sides := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = sides
	return c


static func environment(root: Node3D, sky_top: Color, horizon: Color, fog_col: Color, fog_density: float, ambient: Color) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = sky_top
	sm.sky_horizon_color = horizon
	sm.ground_bottom_color = Color("050507")
	sm.ground_horizon_color = horizon
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = fog_col
	env.fog_density = fog_density
	env.fog_sky_affect = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


static func lights(root: Node3D, moon: Color, rim: Color, key_energy := 1.2) -> void:
	# soft key light from the front-top
	var key := DirectionalLight3D.new()
	key.light_color = moon
	key.light_energy = key_energy
	key.rotation_degrees = Vector3(-35, 20, 0)
	key.shadow_enabled = true
	root.add_child(key)
	# strong rim light from behind — makes fighters pop from the background
	var back := DirectionalLight3D.new()
	back.light_color = rim
	back.light_energy = 2.2
	back.rotation_degrees = Vector3(-20, 180, 0)
	root.add_child(back)


static func moon(root: Node3D, pos: Vector3, r: float, col: Color) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	add_mesh(root, s, pos, mat(col, 1.0, 0.0, col, 3.0))


static func stars(root: Node3D, count: int, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := SphereMesh.new()
	q.radius = 0.06
	q.height = 0.12
	q.radial_segments = 4
	q.rings = 2
	mm.mesh = q
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf_range(-70, 70), rng.randf_range(8, 40), rng.randf_range(-90, -60))))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat(Color.WHITE, 1.0, 0.0, Color(0.9, 0.95, 1.0), 2.5)
	root.add_child(mmi)


static func floor_plane(root: Node3D, m: Material, size := Vector2(80, 60)) -> void:
	if m is StandardMaterial3D:
		m.normal_enabled = false   # a flat, rough floor reads better than bumpy noise
		m.uv1_scale = Vector3(4, 4, 4)
	var p := PlaneMesh.new()
	p.size = size
	add_mesh(root, p, Vector3(0, 0, -size.y / 2 + 6), m)


## Where each painting's horizon sits, as a fraction of its height from the bottom.
const HORIZON := {"training_ground": 0.40, "silent_forest": 0.30, "broken_pass": 0.22,
				  "underground_sanctuary": 0.32, "solar_altar": 0.24}


static func build(id: String, root: Node3D, cam_y := 2.0) -> void:
	if ResourceLoader.exists(backdrop_path(id)):
		_painted(root, id, cam_y)
		return
	match id:
		"silent_forest": _forest(root)
		"broken_pass": _pass(root)
		"underground_sanctuary": _sanctuary(root)
		_: _training_ground(root)


static func backdrop_path(id: String) -> String:
	return "res://assets/backdrops/%s.png" % id


## An arena built around its painted backdrop (assets/backdrops/<id>.png, made on Kaggle):
## sky, fog, ambient and floor colours are sampled from the painting so the 3D floor the
## fighters stand on continues the painted ground, and the painting's horizon is put at the
## camera's eye level so the perspective agrees.
static func _painted(root: Node3D, id: String, cam_y: float) -> void:
	var tex: Texture2D = load(backdrop_path(id))
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var hf: float = HORIZON.get(id, 0.33)
	var sky := _avg_rows(img, 0.0, 0.25)
	var horizon := _avg_rows(img, 1.0 - hf - 0.04, 1.0 - hf + 0.02)
	var ground := _avg_rows(img, 1.0 - hf + 0.04, 1.0 - hf * 0.45)
	environment(root, sky, horizon, horizon.lerp(ground, 0.4), 0.007, sky.lerp(ground, 0.5).lightened(0.1))
	lights(root, sky.lerp(Color.WHITE, 0.55), horizon.lightened(0.25), 1.35)
	floor_plane(root, noise_mat(ground, ground.darkened(0.22), 0.05, 0.92))
	# the painting, its horizon at eye level
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.disable_fog = true
	var dist := 34.0
	var h := 36.0
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var y_bottom := cam_y - hf * h
	var mi := add_mesh(root, q, Vector3(0, y_bottom + h * 0.5, -dist), m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _avg_rows(img: Image, from: float, to: float) -> Color:
	var h := img.get_height()
	var w := img.get_width()
	var y0 := clampi(int(from * h), 0, h - 1)
	var y1 := clampi(int(to * h), y0 + 1, h)
	var acc := Color(0, 0, 0, 0)
	var n := 0
	for y in range(y0, y1, maxi(1, (y1 - y0) / 24)):
		for x in range(0, w, maxi(1, w / 64)):
			acc += img.get_pixel(x, y)
			n += 1
	return Color(acc.r / n, acc.g / n, acc.b / n)


# ------------------------------------------------------------------ locations

static func _training_ground(root: Node3D) -> void:
	environment(root, Color("04050a"), Color("141a28"), Color("0d1220"), 0.06, Color("2a2a34"))
	lights(root, Color("aab6d8"), Color("8fb0ff"), 0.7)
	stars(root, 260, 4)
	moon(root, Vector3(18, 22, -80), 3.0, Color("dfe8ff"))
	floor_plane(root, noise_mat(Color("17161a"), Color("26242a"), 0.18, 0.95))
	var stone := noise_mat(Color("2a2830"), Color("3c3944"), 0.15, 0.85)
	# steps behind the fighters
	for s in 3:
		add_mesh(root, box(9.0 + s * 2.0, 0.25, 1.2), Vector3(0, 0.125 + (2 - s) * 0.25, -3.5 - s * 1.2), stone)
	# rows of pillars (some broken) receding into the fog
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row in 3:
		for i in 7:
			var x := -15.0 + i * 5.0 + row * 2.0
			var z := -6.0 - row * 7.0
			var h := rng.randf_range(4.0, 7.5) if (i + row) % 3 != 1 else rng.randf_range(1.5, 3.0)
			add_mesh(root, cyl(0.45, 0.55, h), Vector3(x, h / 2, z), stone)
			add_mesh(root, box(1.4, 0.35, 1.4), Vector3(x, 0.17, z), stone)
			if h > 3.5:
				add_mesh(root, box(1.3, 0.3, 1.3), Vector3(x, h + 0.15, z), stone)
	# broken practice swords on the floor
	var wood := mat(Color("4a3622"), 0.9)
	for i in 10:
		add_mesh(root, box(rng.randf_range(0.6, 1.1), 0.05, 0.08), Vector3(rng.randf_range(-8, 8), 0.03, rng.randf_range(-3, 1.5)), wood,
			Vector3(0, rng.randf_range(0, TAU), 0))
	# lantern with warm light
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffb060")
	lamp.light_energy = 3.0
	lamp.omni_range = 7.0
	lamp.position = Vector3(-6.5, 1.0, -1.5)
	root.add_child(lamp)
	var bulb := SphereMesh.new()
	bulb.radius = 0.12
	bulb.height = 0.24
	add_mesh(root, bulb, Vector3(-6.5, 0.6, -1.5), mat(Color("ffc070"), 1.0, 0.0, Color("ffb060"), 6.0))


static func _forest(root: Node3D) -> void:
	environment(root, Color("030405"), Color("10161c"), Color("1a2028"), 0.07, Color("25303a"))
	lights(root, Color("9fb0c8"), Color("b8ccdd"), 0.9)
	floor_plane(root, noise_mat(Color("0e1114"), Color("1c2126"), 0.08))
	var bark := noise_mat(Color("12161a"), Color("232a30"), 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 46:
		var z := rng.randf_range(-40, -3)
		var x := rng.randf_range(-30, 30)
		if absf(x) < 3.0 and z > -6.0:
			continue
		var h := rng.randf_range(7, 14)
		add_mesh(root, cyl(0.12, 0.3, h, 7), Vector3(x, h / 2, z), bark)
		for b in 3:
			var bl := rng.randf_range(1.0, 2.5)
			add_mesh(root, cyl(0.03, 0.08, bl, 5), Vector3(x + 0.4, h * rng.randf_range(0.5, 0.9), z), bark,
				Vector3(0, rng.randf_range(0, TAU), deg_to_rad(rng.randf_range(35, 70))))


static func _pass(root: Node3D) -> void:
	environment(root, Color("06050a"), Color("1c1820"), Color("1a1418"), 0.04, Color("30282c"))
	lights(root, Color("c8b8b0"), Color("ffb39a"), 1.0)
	stars(root, 120, 14)
	floor_plane(root, noise_mat(Color("221c1a"), Color("3a302c"), 0.07))
	var rock := noise_mat(Color("1c1719"), Color("332a2c"), 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	# cliff walls on both sides and far peaks
	for side in [-1, 1]:
		for k in 6:
			var w := rng.randf_range(4, 8)
			var h := rng.randf_range(8, 18)
			add_mesh(root, box(w, h, 5), Vector3(side * rng.randf_range(11, 18), h / 2 - 1, -4 - k * 6), rock,
				Vector3(0, rng.randf_range(-0.4, 0.4), side * rng.randf_range(0.05, 0.2)))
	for k in 8:
		var h2 := rng.randf_range(12, 25)
		add_mesh(root, cyl(0.5, rng.randf_range(6, 10), h2, 6), Vector3(rng.randf_range(-40, 40), h2 / 2 - 2, -70), rock)
	# boulders (pieces of the broken blocking stone)
	for i in 12:
		var s := SphereMesh.new()
		var r := rng.randf_range(0.3, 1.2)
		s.radius = r
		s.height = r * 1.6
		add_mesh(root, s, Vector3(rng.randf_range(-10, 10), r * 0.5, rng.randf_range(-12, -2.5)), rock)


static func _sanctuary(root: Node3D) -> void:
	environment(root, Color("0a080c"), Color("1a1418"), Color("140f12"), 0.05, Color("3a2c28"))
	lights(root, Color("c8a890"), Color("ffcfa0"), 0.8)
	floor_plane(root, noise_mat(Color("1d171a"), Color("2c2427"), 0.09))
	var stone := noise_mat(Color("1f191d"), Color("30272b"), 0.12)
	# back wall, vaulted columns, shelves
	add_mesh(root, box(60, 14, 1), Vector3(0, 7, -9), stone)
	for i in 9:
		var x := -16.0 + i * 4.0
		add_mesh(root, box(0.9, 9, 0.9), Vector3(x, 4.5, -7.5), stone)
	var wood := mat(Color("3a2a1e"), 0.85)
	var jar := mat(Color("2a2229"), 0.6)
	for s in 3:
		var sx := -9.0 + s * 9.0
		for row in 3:
			add_mesh(root, box(3.0, 0.1, 0.6), Vector3(sx, 1.2 + row * 1.0, -8.2), wood)
			for k in 5:
				add_mesh(root, cyl(0.12, 0.14, 0.4, 8), Vector3(sx - 1.2 + k * 0.6, 1.45 + row * 1.0, -8.2), jar)
	# the crystal necklace glint
	var glint := OmniLight3D.new()
	glint.light_color = Color("ff9ccf")
	glint.light_energy = 1.5
	glint.omni_range = 2.0
	glint.position = Vector3(0, 1.5, -7.8)
	root.add_child(glint)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffb060")
	lamp.light_energy = 3.5
	lamp.omni_range = 9.0
	lamp.position = Vector3(8, 4, -5)
	root.add_child(lamp)
