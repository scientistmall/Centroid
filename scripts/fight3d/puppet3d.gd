class_name Puppet3D
extends Node3D
## Stand-in 3D fighter (until the Mixamo models arrive): a mannequin built from
## shaded 3D parts and posed every frame from the logic fighter's pose data,
## so it moves exactly like the fight logic expects.

const PPM := Stage3D.PPM

var fighter: Fighter
var stage: Stage3D
var _body_mat: StandardMaterial3D
var _back_mat: StandardMaterial3D
var _accent_mat: StandardMaterial3D
var _parts := {}
var _meshes: Array[MeshInstance3D] = []
var _hair: Array = []      # [MeshInstance3D, local offset from head, direction]
var _scarf: Array = []
var _rim_light: OmniLight3D


func setup(f: Fighter, s: Stage3D) -> void:
	fighter = f
	stage = s
	var col := f.color
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color("2a2d38")
	_body_mat.metallic = 0.55
	_body_mat.roughness = 0.35
	_body_mat.rim_enabled = true
	_body_mat.rim = 1.0
	_body_mat.rim_tint = 0.6
	_body_mat.emission_enabled = true
	_body_mat.emission = col
	_body_mat.emission_energy_multiplier = 0.06
	_back_mat = _body_mat.duplicate()
	_back_mat.albedo_color = Color("121319")
	_accent_mat = StandardMaterial3D.new()
	_accent_mat.albedo_color = col
	_accent_mat.emission_enabled = true
	_accent_mat.emission = col
	_accent_mat.emission_energy_multiplier = 2.2
	var bulk: float = f.costume.get("bulk", 1.0)
	# limbs: tapered cylinders (scaled along Y to segment length) + joint spheres
	for side in ["f", "b"]:
		var m := _body_mat if side == "f" else _back_mat
		_parts["thigh_" + side] = _cyl(0.085 * bulk, 0.065 * bulk, m)
		_parts["shin_" + side] = _cyl(0.065 * bulk, 0.05 * bulk, m)
		_parts["uarm_" + side] = _cyl(0.06 * bulk, 0.05 * bulk, m)
		_parts["farm_" + side] = _cyl(0.05 * bulk, 0.042 * bulk, m)
		_parts["knee_" + side] = _sphere(0.068 * bulk, m)
		_parts["elbow_" + side] = _sphere(0.055 * bulk, m)
		_parts["hand_" + side] = _sphere(0.055 * bulk, m)
		_parts["boot_" + side] = _box(Vector3(0.24, 0.1, 0.12), m)
		_parts["bracer_" + side] = _cyl(0.056 * bulk, 0.056 * bulk, _accent_mat if f.costume.get("bracers", false) else m)
	_parts["torso"] = _box(Vector3(0.36 * bulk, 1.0, 0.22 * bulk), _body_mat)
	_parts["pelvis"] = _box(Vector3(0.3 * bulk, 0.16, 0.2 * bulk), _body_mat)
	_parts["belt"] = _box(Vector3(0.32 * bulk, 0.04, 0.215 * bulk), _accent_mat)
	_parts["neck"] = _cyl(0.05, 0.06, _body_mat)
	_parts["head"] = _sphere(0.13, _body_mat)
	_parts["eye"] = _box(Vector3(0.06, 0.012, 0.02), _accent_mat)
	if f.costume.get("shoulder", "") == "pauldron":
		_parts["pauldron"] = _sphere(0.13 * bulk, _body_mat)
		_parts["pauldron"].scale = Vector3(1.2, 0.7, 1.0)
	_build_hair(f.costume.get("hair_style", "short"))
	if f.costume.has("scarf"):
		for i in 5:
			var b := _box(Vector3(0.24, 0.06, 0.03), _accent_mat if i == 0 else _scarf_mat(f.costume["scarf"].get("color", "#ffffff")))
			_scarf.append(b)
	_build_weapon(f.weapon)
	# coloured back-light: gives each fighter a rim glow in their colour
	_rim_light = OmniLight3D.new()
	_rim_light.light_color = col
	_rim_light.light_energy = 3.0
	_rim_light.omni_range = 2.6
	_rim_light.position = Vector3(0, 1.2, -0.9)
	add_child(_rim_light)
	var fill := OmniLight3D.new()
	fill.light_color = col.lightened(0.5)
	fill.light_energy = 0.6
	fill.omni_range = 3.0
	fill.position = Vector3(0, 1.4, 1.4)
	add_child(fill)


func _scarf_mat(c: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = 0.8
	m.rim_enabled = true
	return m


func _mesh(mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	add_child(mi)
	_meshes.append(mi)
	return mi


func _cyl(r_top: float, r_bot: float, m: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = 1.0
	c.radial_segments = 10
	return _mesh(c, m)


func _sphere(r: float, m: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return _mesh(s, m)


func _box(size: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, m)


func _build_hair(style: String) -> void:
	var spikes := []
	match style:
		"spiky":
			for k in 7:
				spikes.append([Vector2(-0.02 - k * 0.025, 0.08 - (k % 2) * 0.02), Vector2(-0.6 - k * 0.12, 0.8 - k * 0.15).normalized(), 0.16 + (k % 2) * 0.05])
		"mohawk":
			for k in 6:
				spikes.append([Vector2(0.06 - k * 0.04, 0.11), Vector2(-0.35 - k * 0.1, 1.0).normalized(), 0.14 + (k % 2) * 0.04])
		"long":
			spikes.append([Vector2(-0.08, 0.0), Vector2(-0.3, -1.0).normalized(), 0.3])
		_:
			spikes.append([Vector2(-0.03, 0.06), Vector2(-0.8, 0.5).normalized(), 0.12])
	for s in spikes:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.045
		c.height = 1.0
		c.radial_segments = 6
		var mi := _mesh(c, _body_mat)
		_hair.append([mi, s[0], s[1], s[2]])


func _build_weapon(kind: String) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("aab4c4")
	steel.metallic = 0.9
	steel.roughness = 0.25
	match kind:
		"sword", "flex_blade", "twin_swords", "crystal_blades", "daggers":
			_parts["blade"] = _box(Vector3(0.05, 1.0, 0.012), steel)
			_parts["edge"] = _box(Vector3(0.012, 1.0, 0.014), _accent_mat)
			_parts["guard"] = _box(Vector3(0.14, 0.03, 0.05), _body_mat)
			_parts["grip"] = _cyl(0.02, 0.02, _body_mat)
		"axe":
			_parts["grip"] = _cyl(0.025, 0.025, _body_mat)
			_parts["axe_head"] = _box(Vector3(0.36, 0.3, 0.025), steel)
			_parts["edge"] = _box(Vector3(0.02, 0.34, 0.03), _accent_mat)
		"spear":
			_parts["grip"] = _cyl(0.02, 0.02, _body_mat)
			_parts["blade"] = _box(Vector3(0.06, 0.25, 0.012), steel)
		"whip":
			_parts["grip"] = _cyl(0.012, 0.012, _accent_mat)
		_:
			pass


# ------------------------------------------------------------------ posing

func _v(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x / PPM, -p.y / PPM, z)


func _orient(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.0001:
		return
	var y := d / L
	var x := y.cross(Vector3.BACK)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y * L, z), (a + b) * 0.5)


func _place(name: String, pos: Vector3) -> void:
	if _parts.has(name):
		_parts[name].position = pos


func sync() -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	position = stage.to_world(fighter.position)
	var pose := fighter.current_pose()
	var facing := fighter.facing
	var j := FighterPainter.joints(pose, facing)
	rotation.z = -deg_to_rad(pose.get("rot", 0.0)) * facing
	var zf := 0.11
	var zb := -0.11
	for side in ["f", "b"]:
		var z := zf if side == "f" else zb
		var hip := _v(j["hip"], z * 0.6)
		var knee := _v(j["knee_" + side], z)
		var foot := _v(j["foot_" + side], z)
		var sh := _v(j["shoulder"], z * 1.4)
		var elbow := _v(j["elbow_" + side], z * 1.5)
		var hand := _v(j["hand_" + side], z * 1.5)
		_orient(_parts["thigh_" + side], hip, knee)
		_orient(_parts["shin_" + side], knee, foot)
		_orient(_parts["uarm_" + side], sh, elbow)
		_orient(_parts["farm_" + side], elbow, hand)
		_parts["knee_" + side].position = knee
		_parts["elbow_" + side].position = elbow
		_parts["hand_" + side].position = hand
		_parts["boot_" + side].position = foot + Vector3(0.06 * facing, 0.03, 0)
		var bm: MeshInstance3D = _parts["bracer_" + side]
		_orient(bm, elbow.lerp(hand, 0.45), elbow.lerp(hand, 0.75))
	var hip_c := _v(j["hip"], 0.0)
	var sh_c := _v(j["shoulder"], 0.0)
	var head := _v(j["head"], 0.0)
	_orient(_parts["torso"], hip_c + (sh_c - hip_c) * 0.05, sh_c)
	_parts["pelvis"].position = hip_c
	_parts["belt"].position = hip_c + (sh_c - hip_c).normalized() * 0.08
	_orient(_parts["neck"], sh_c, head)
	_parts["head"].position = head
	_parts["eye"].position = head + Vector3(0.09 * facing, 0.0, 0.1)
	if _parts.has("pauldron"):
		_parts["pauldron"].position = sh_c + Vector3(0.03 * facing, 0.02, zf * 1.6)
	for h in _hair:
		var base := head + Vector3(h[1].x * facing, h[1].y, 0.0)
		var dir := Vector3(h[2].x * facing, h[2].y, 0.0)
		_orient(h[0], base, base + dir * h[3] + Vector3(-fighter.sec.x * 0.002, 0, 0))
	for i in _scarf.size():
		var u := float(i + 1) / _scarf.size()
		var flutter := sin(fighter.clock * 7.0 - u * 5.0) * 0.06 * u
		_scarf[i].position = sh_c + Vector3(-facing * (0.05 + u * 0.75), 0.05 - u * 0.1 + flutter, -0.05) + Vector3(fighter.sec.x, -fighter.sec.y, 0) * 0.004 * u
		_scarf[i].rotation.z = flutter * 3.0
	_pose_weapon(j, pose, facing)
	# hit flash and veil transparency
	_body_mat.emission = fighter.color.lerp(Color.WHITE, 0.5)
	_body_mat.emission_energy_multiplier = 0.06 + fighter.flash * 0.7
	var tr := 1.0 - fighter.modulate.a
	for mi in _meshes:
		mi.transparency = tr


func _pose_weapon(j: Dictionary, pose: Dictionary, facing: int) -> void:
	var hand := _v(j["hand_f"], 0.18)
	var r := deg_to_rad(pose["wpn"])
	var d := Vector3(sin(r) * facing, -cos(r), 0.0)
	match fighter.weapon:
		"sword", "flex_blade", "twin_swords", "crystal_blades", "daggers":
			var L := FighterPainter.weapon_length(fighter.weapon) / PPM
			_orient(_parts["grip"], hand - d * 0.16, hand + d * 0.04)
			_parts["guard"].transform = Transform3D(Basis(Vector3.BACK, atan2(d.y, d.x)), hand + d * 0.05)
			_orient(_parts["blade"], hand + d * 0.06, hand + d * L)
			_orient(_parts["edge"], hand + d * 0.06 + Vector3(0, 0, 0.0), hand + d * L)
		"axe":
			var L2 := FighterPainter.weapon_length("axe") / PPM
			_orient(_parts["grip"], hand - d * 0.2, hand + d * L2)
			var n := Vector3(-d.y, d.x, 0) * facing
			var hd := hand + d * (L2 - 0.18)
			_parts["axe_head"].transform = Transform3D(Basis(Vector3.BACK, atan2(d.y, d.x) - PI / 2), hd + n * 0.16)
			_parts["edge"].transform = Transform3D(Basis(Vector3.BACK, atan2(d.y, d.x) - PI / 2), hd + n * 0.33)
		"spear":
			var L3 := FighterPainter.weapon_length("spear") / PPM
			_orient(_parts["grip"], hand - d * 0.5, hand + d * L3)
			_orient(_parts["blade"], hand + d * L3, hand + d * (L3 + 0.25))
		"whip":
			_orient(_parts["grip"], hand, hand + d * 0.3)
