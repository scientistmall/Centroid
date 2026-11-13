class_name Model3D
extends Node3D
## A fighter drawn as the real rigged 3D character (Mixamo skeleton + shared animation library).
## Same interface as Puppet3D: setup(fighter, stage) once, sync() every frame.
## Used when assets/characters/<id>/<id>.tscn exists (made by tools/models/fix_rig.gd).
##
## Attacks and powers are not played at clip speed: each clip's strike moment (measured by
## tools/models/build_anims.gd) is lined up with the move's hit frame, so the animation always
## agrees with the hitbox, whatever the move's startup / active / recovery times are.

const LIB_PATH := "res://assets/animations/centroid_anims.res"
## clips not uploaded yet -> closest available stand-in
const FALLBACK := {
	"light_1": "heavy_2", "light_2": "heavy_1", "light_3": "air_attack",
	"walk_forward": "idle", "walk_back": "idle", "knockdown": "defeat", "victory": "buff",
}
const POWER_CLIP := {
	"projectile": "cast_1", "lash": "cast_1", "drain": "cast_1", "pull": "cast_1",
	"burst": "cast_2", "wall": "cast_2", "summon": "cast_2", "buff": "buff", "dash": "dash",
}
const TURN := 0.38  # radians the body turns toward the camera from pure profile
const SHADER := preload("res://assets/shaders/character.gdshader")
## crossfade time when switching into each kind of clip
const BLEND := {"idle": 0.18, "walk_forward": 0.15, "walk_back": 0.15, "block": 0.08, "jump": 0.1}

static var _lib: AnimationLibrary

var fighter: Fighter
var stage: Stage3D
var _ap: AnimationPlayer
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _clip := ""
var _yaw := 0.0
var _tip: Node3D            # weapon tip / mid markers (for trails and particles)
var _mid: Node3D
var _sp_pos := Vector3.ZERO  # secondary-motion spring (world metres)
var _sp_vel := Vector3.ZERO
var _t := 0.0
var _last_state := -1


static func available(char_id: String) -> bool:
	return char_id != "" and ResourceLoader.exists(scene_path(char_id)) and ResourceLoader.exists(LIB_PATH)


static func scene_path(char_id: String) -> String:
	return "res://assets/characters/%s/%s.tscn" % [char_id, char_id]


func setup(f: Fighter, s: Stage3D) -> void:
	fighter = f
	stage = s
	if _lib == null:
		_lib = load(LIB_PATH)
	var model: Node3D = (load(scene_path(f.char_id)) as PackedScene).instantiate()
	add_child(model)
	var rig: Node3D = model.get_child(0)  # the scaled node that holds Skeleton3D
	_mesh = model.find_children("*", "MeshInstance3D", true, false)[0]
	_ap = AnimationPlayer.new()
	rig.add_child(_ap)  # root_node ".." -> tracks "Skeleton3D:mixamorig_*" resolve
	_ap.add_animation_library("", _lib)
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# one shader for texture, rim, hit flash and hair / cloth motion
	var src := _mesh.get_active_material(0) as BaseMaterial3D
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("albedo_tex", src.albedo_texture if src else null)
	_mat.set_shader_parameter("use_flex", (_mesh.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0)
	_mat.set_shader_parameter("model_height", _mesh.mesh.get_aabb().size.y)
	_mat.set_shader_parameter("flash_color", f.color.lerp(Color.WHITE, 0.6))
	_mesh.material_override = _mat
	_build_weapon(rig, f.weapon, f.color)
	# coloured back-light and soft fill, as for the mannequin
	var col := f.color
	var rim := OmniLight3D.new()
	rim.light_color = col
	rim.light_energy = 3.0
	rim.omni_range = 2.6
	rim.position = Vector3(0, 1.2, -0.9)
	add_child(rim)
	var fill := OmniLight3D.new()
	fill.light_color = col.lightened(0.5)
	fill.light_energy = 0.6
	fill.omni_range = 3.0
	fill.position = Vector3(0, 1.4, 1.4)
	add_child(fill)
	_yaw = _target_yaw()
	if _tip:
		f.tip_source = _tip_2d
	sync()


## The weapon tip and mid-blade in the fighter's 2D space (for trails and element particles).
func _tip_2d() -> Array:
	var base := fighter.position
	return [stage.to_logic(_tip.global_position) - base, stage.to_logic(_mid.global_position) - base]


## Simple weapon held in the right hand until real weapon models exist. Built in metres with the
## grip at the origin and the blade along +Y, then turned so the blade points forward out of
## the fist (perpendicular to the fingers) in the rest pose.
func _build_weapon(rig: Node3D, kind: String, col: Color) -> void:
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var hand := sk.find_bone("mixamorig_RightHand")
	if hand < 0 or kind in ["gauntlets", ""]:
		return
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("aab4c4")
	steel.metallic = 0.9
	steel.roughness = 0.25
	var glow := StandardMaterial3D.new()
	glow.albedo_color = col
	glow.emission_enabled = true
	glow.emission = col
	glow.emission_energy_multiplier = 2.2
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1b1d24")
	var w := Node3D.new()
	match kind:
		"sword", "flex_blade", "twin_swords", "crystal_blades":
			_part(w, _boxm(Vector3(0.045, 0.82, 0.01)), steel, Vector3(0, 0.5, 0))
			_part(w, _boxm(Vector3(0.012, 0.82, 0.013)), glow, Vector3(0.02, 0.5, 0))
			_part(w, _boxm(Vector3(0.14, 0.025, 0.045)), dark, Vector3(0, 0.08, 0))
			_part(w, _cylm(0.018, 0.17), dark, Vector3(0, 0.0, 0))
		"daggers":
			_part(w, _boxm(Vector3(0.035, 0.3, 0.01)), steel, Vector3(0, 0.22, 0))
			_part(w, _cylm(0.016, 0.12), dark, Vector3.ZERO)
		"axe":
			_part(w, _cylm(0.022, 0.85), dark, Vector3(0, 0.25, 0))
			_part(w, _boxm(Vector3(0.3, 0.26, 0.022)), steel, Vector3(0.14, 0.58, 0))
			_part(w, _boxm(Vector3(0.02, 0.3, 0.028)), glow, Vector3(0.29, 0.58, 0))
		"spear":
			_part(w, _cylm(0.018, 1.7), dark, Vector3(0, 0.3, 0))
			_part(w, _boxm(Vector3(0.05, 0.24, 0.01)), steel, Vector3(0, 1.25, 0))
			_part(w, _boxm(Vector3(0.012, 0.24, 0.013)), glow, Vector3(0.0, 1.25, 0.004))
		"whip":
			_part(w, _cylm(0.014, 0.2), glow, Vector3.ZERO)
		_:
			return
	var reach: float = {"axe": 0.7, "spear": 1.37, "whip": 0.1, "daggers": 0.37}.get(kind, 0.92)
	_tip = Node3D.new()
	_tip.position = Vector3(0, reach, 0)
	w.add_child(_tip)
	_mid = Node3D.new()
	_mid.position = Vector3(0, reach * 0.45, 0)
	w.add_child(_mid)
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_RightHand"
	sk.add_child(att)
	att.add_child(w)
	# rest-pose hand frame (skeleton units); blade forward (+Z of the model), edge up
	var hb := sk.get_bone_global_rest(hand).basis.orthonormalized()
	var want := Basis(Vector3.UP, Vector3.FORWARD * -1.0, Vector3.RIGHT)  # x=up, y=+Z (forward), z=right
	w.basis = (hb.inverse() * want).scaled(Vector3.ONE / rig.scale.x)
	# grip in the palm: a little way along the fingers (+Y of Mixamo hand bones)
	w.position = Vector3(0, 0.07 / rig.scale.x, 0.02 / rig.scale.x)


static func _boxm(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cylm(r: float, h: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	return m


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _target_yaw() -> float:
	# the model faces +Z; +PI/2 turns it to face +X (screen right)
	return fighter.facing * (PI / 2.0 - TURN)


func _has(clip: String) -> bool:
	return _lib.has_animation(clip)


func _pick(clip: String) -> String:
	if _has(clip):
		return clip
	var fb: String = FALLBACK.get(clip, "idle")
	return fb if _has(fb) else "idle"


## [clip, time] for the current state; time < 0 means "play freely".
func _choose() -> Array:
	var f := fighter
	var t := f.state_time
	match f.state:
		Fighter.S.IDLE, Fighter.S.FROZEN:
			return ["idle", -1.0]
		Fighter.S.WALK:
			return [_pick("walk_forward" if f.vel.x * f.facing >= 0.0 else "walk_back"), -1.0]
		Fighter.S.AIR:
			var j := _pick("jump")
			var s: float = _lib.get_animation(j).get_meta("strike", 0.5)
			return [j, minf(s - 0.1 + t, _lib.get_animation(j).length - 0.05)]
		Fighter.S.BLOCK:
			return ["block", -1.0]
		Fighter.S.BLOCKSTUN:
			return [_pick("block_hit"), t]
		Fighter.S.HURT:
			var heavy := f.vel.y < -200.0 or absf(f.vel.x) > 500.0
			return [_pick("hit_heavy" if heavy else "hit_light"), t * 1.3]
		Fighter.S.KO:
			return [_pick("knockdown"), t]
		Fighter.S.WIN:
			return [_pick("victory"), t]
		Fighter.S.ATTACK:
			var clip := "air_attack"
			if f.move_kind == "light":
				clip = "light_%d" % (f.chain_index + 1)
			elif f.move_kind == "heavy":
				clip = "heavy_%d" % (f.chain_index + 1)
			clip = _pick(clip)
			return [clip, _timeline(clip, t, f.move.get("startup", 0.1), f.move.get("active", 0.08), f.move.get("recovery", 0.2))]
		Fighter.S.POWER:
			var pd := f.power_def
			var pc := _pick(POWER_CLIP.get(pd.get("type", ""), "cast_1"))
			return [pc, _timeline(pc, t, pd.get("startup", 0.2), pd.get("active", 0.1), pd.get("recovery", 0.3))]
	return ["idle", -1.0]


## Map game time in a move to clip time so the clip's strike lands on the move's active frame.
func _timeline(clip: String, t: float, su: float, ac: float, re: float) -> float:
	var a := _lib.get_animation(clip)
	var s: float = a.get_meta("strike", a.length * 0.4)
	var wind := minf(s, 0.45)
	var follow := clampf(a.length - s - 0.1, 0.0, 0.6)
	if t < su:
		return s - wind + wind * (t / maxf(su, 0.001))
	if t < su + ac:
		return s + 0.1 * ((t - su) / maxf(ac, 0.001))
	return minf(s + 0.1 + follow * ((t - su - ac) / maxf(re, 0.001)), a.length)


func sync() -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	var dt := get_process_delta_time()
	if dt <= 0.0:
		dt = 1.0 / 60.0
	_t += dt
	position = stage.to_world(fighter.position)
	_yaw = lerp_angle(_yaw, _target_yaw(), 0.35)
	rotation.y = _yaw
	_animate(dt)
	_secondary(dt)
	_mat.set_shader_parameter("flash", clampf(fighter.flash, 0.0, 1.0) * 0.45)
	_mesh.transparency = 1.0 - fighter.modulate.a


## Drive the AnimationPlayer by hand so every switch crossfades, even for time-mapped attacks.
func _animate(dt: float) -> void:
	var pick := _choose()
	var clip: String = pick[0]
	var time: float = pick[1]
	var new_state := fighter.state != _last_state
	_last_state = fighter.state
	var length := _lib.get_animation(clip).length
	if clip != _clip or (new_state and time >= 0.0 and time < _ap.current_animation_position - 0.05):
		_ap.play(clip, BLEND.get(clip, 0.07))
		if time >= 0.0:
			_ap.seek(clampf(time, 0.0, length), false)
		_clip = clip
	if time < 0.0:
		var rate := 1.0
		if fighter.state == Fighter.S.WALK:
			rate = clampf(absf(fighter.vel.x) / maxf(fighter.walk_speed, 1.0), 0.6, 1.5)
		_ap.advance(dt * rate)
	else:
		var d := clampf(time, 0.0, length) - _ap.current_animation_position
		if d < -0.001 or d > 0.6:
			_ap.seek(clampf(time, 0.0, length), false)
			d = 0.0
		_ap.advance(maxf(d, 0.0))


## Spring that lags behind movement; the shader bends coats and hair by it.
func _secondary(dt: float) -> void:
	var v := Vector3(fighter.vel.x, -fighter.vel.y, 0.0) / Stage3D.PPM
	var target := Vector3(-v.x * 0.07, -v.y * 0.035, 0.0)
	if fighter.state == Fighter.S.HURT:
		target.x += fighter.facing * 0.12
	if target.length() > 0.28:
		target = target.normalized() * 0.28
	var acc := (target - _sp_pos) * 70.0 - _sp_vel * 9.0
	_sp_vel += acc * dt
	_sp_pos += _sp_vel * dt
	var to_local := _mesh.global_transform.basis.inverse()
	_mat.set_shader_parameter("sway", to_local * _sp_pos)
	_mat.set_shader_parameter("wind", (to_local * Vector3(0.012, 0, 0)).length())
	_mat.set_shader_parameter("time_s", _t)
