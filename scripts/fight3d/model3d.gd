class_name Model3D
extends Node3D
## A fighter drawn as the real rigged 3D character (Mixamo skeleton + shared animation library).
## Same interface as Puppet3D: setup(fighter, stage) once, sync() every frame.
## Used when assets/characters/<id>/<id>.vrm exists (VRoid Studio export; preferred) or
## assets/characters/<id>/<id>.tscn (Mixamo rig made by tools/models/fix_rig.gd).
## A VRM body gets the same clips retargeted onto its humanoid skeleton (VrmRetarget), its own
## spring-bone hair and cloth, anime (MToon) shading, and fingers closed around the weapon.
##
## Attacks and powers are not played at clip speed: each clip's strike moment (measured by
## tools/models/build_anims.gd) is lined up with the move's hit frame, so the animation always
## agrees with the hitbox, whatever the move's startup / active / recovery times are.

const LIB_PATH := "res://assets/animations/centroid_anims.res"
## clips not uploaded yet -> closest available stand-in
const FALLBACK := {
	"light_1": "heavy_2", "light_2": "heavy_1", "light_3": "air_attack",
	"walk_forward": "idle", "walk_back": "idle", "knockdown": "defeat", "victory": "buff",
	"run": "walk_forward",
}
const POWER_CLIP := {
	"projectile": "cast_1", "lash": "cast_1", "drain": "cast_1", "pull": "cast_1",
	"burst": "cast_2", "wall": "cast_2", "summon": "cast_2", "buff": "buff", "dash": "light_2",
}
const TURN := 0.72  # radians the body turns toward the camera from pure profile (three-quarter view)
const SHADER := preload("res://assets/shaders/character.gdshader")
## crossfade time (real seconds) when switching into each kind of clip; actions use ACTION_BLEND
const BLEND := {"idle": 0.18, "walk_forward": 0.12, "walk_back": 0.12, "block": 0.08, "jump": 0.1, "run": 0.12}
const ACTION_BLEND := 0.07
const MAX_WIND_SPEED := 2.0      # a wind-up never plays faster than this (it stays readable)
const MAX_RECOVER_SPEED := 1.6

static var _lib: AnimationLibrary
## per-fighter sets (data "anim_set"): assets/animations/<set>/<set>_anims.res, merged over the shared clips
static var _sets := {}
var _anims: AnimationLibrary   # this fighter's clips (shared, overridden by its own set)
## fighters stand this tall (metres), as the Mixamo models do
const HEIGHT := 1.78
const HEAD_AT := 0.855      # head joint height as a fraction of body height (hair not counted)
const LOOK := 0.85          # how much of the body's turn toward the camera the head undoes
const OVERLAY := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float rim = 0.3;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = color.rgb * (flash + rim * f);
}
"""
## weapon-hand finger curl (degrees) for proximal / intermediate / distal joints
const CURL := [72.0, 88.0, 55.0]
static var _weapon_specs := {}  # owner char_id -> spec from assets/weapons/weapons.json
const WEAPONS_JSON := "res://assets/weapons/weapons.json"

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
var _serial := -1            # Fighter.state_serial last seen: a new one restarts a time-mapped clip
var _alt := false            # alternate clip name (alias) so a restart of the same clip crossfades
var _vrm := false
var _meshes: Array[MeshInstance3D] = []
var _overlay: ShaderMaterial
var _sk: Skeleton3D
var _grip: Array = []        # [[bone, pose rotation]] holding the weapon
var _ik: TwoBoneIK3D         # (unused; kept for older callers)
var _two_handed := false     # left fist is driven onto the weapon's grip by _left_hand_ik()
var _weapon: Node3D          # the held weapon (child of the right-hand attachment)
var _lgrip := Vector3.ZERO   # where the left fist closes, in the weapon's own space
var _hold := 0.0             # 0..1 how firmly the left hand is on the weapon
var _span := 0.12            # distance between the two fists on the grip
var _w_hand_xf := Transform3D.IDENTITY   # the weapon relative to the right hand (one-handed)
var _two_w := 0.0
var _wnode: Node3D           # the weapon; shown only while a power runs (summoned, then gone)
var _wshow := 0.0            # 0..1 how far the weapon is summoned
var _w_base_scale := Vector3.ONE   # the weapon's attachment scale, read once it is placed
const SUMMON_IN := 0.16      # seconds for the weapon to flash into the hands
const SUMMON_OUT := 0.3      # seconds for it to dissolve after the power            # 0 = weapon follows the right hand, 1 = hilt through both fists


static func available(char_id: String) -> bool:
	return char_id != "" and ResourceLoader.exists(LIB_PATH) \
		and (ResourceLoader.exists(vrm_path(char_id)) or ResourceLoader.exists(hy_path(char_id))
			or ResourceLoader.exists(scene_path(char_id)))


## A fighting style's own clip set (tools/models/anim_sets.py), or the shared clips without one.
## A set is complete on its own: its clips share one skeleton (meta "ref"), so they are never
## mixed with the shared ones, which were made on another.
static func _merged(set_name: String) -> AnimationLibrary:
	var path := "res://assets/animations/%s/%s_anims.res" % [set_name, set_name]
	if set_name == "" or not ResourceLoader.exists(path):
		return _lib
	if not _sets.has(set_name):
		_sets[set_name] = load(path)
	return _sets[set_name]


## A Hunyuan 3D character rigged by tools/models/hy_rig.py (humanoid bone names, flex colours).
static func hy_path(char_id: String) -> String:
	return "res://assets/characters/%s/%s_hy.glb" % [char_id, char_id]


static func vrm_path(char_id: String) -> String:
	return "res://assets/characters/%s/%s.vrm" % [char_id, char_id]


static func scene_path(char_id: String) -> String:
	return "res://assets/characters/%s/%s.tscn" % [char_id, char_id]


func setup(f: Fighter, s: Stage3D) -> void:
	fighter = f
	stage = s
	if _lib == null:
		_lib = load(LIB_PATH)
	# a fighting style's own set (made on Mixamo's standard skeleton) needs a retargeted body
	var humanoid := ResourceLoader.exists(vrm_path(f.char_id)) or ResourceLoader.exists(hy_path(f.char_id))
	_anims = _merged(str(f.data.get("anim_set", ""))) if humanoid else _lib
	if ResourceLoader.exists(vrm_path(f.char_id)):
		_setup_humanoid(f, vrm_path(f.char_id), false)
	elif ResourceLoader.exists(hy_path(f.char_id)):
		_setup_humanoid(f, hy_path(f.char_id), true)
	else:
		_setup_mixamo(f)
	# coloured back-light and soft fill, as for the mannequin. Each light is another pass over a
	# 60k-triangle body: phones keep only the rim on HIGH, LOW / SAFE use the scene lights alone.
	var col := f.color
	if not ArenaBuilder.low:
		var rim := OmniLight3D.new()
		rim.light_color = col
		rim.light_energy = 3.0
		rim.omni_range = 2.6
		rim.position = Vector3(0, 1.2, -0.9)
		add_child(rim)
	if not ArenaBuilder.low and not OS.has_feature("mobile"):
		var fill := OmniLight3D.new()
		fill.light_color = col.lightened(0.5)
		fill.light_energy = 0.6
		fill.omni_range = 3.0
		fill.position = Vector3(0, 1.4, 1.4)
		add_child(fill)
	_yaw = _target_yaw()
	f.strike_source = strike_point_2d
	if _tip:
		f.tip_source = _tip_2d
	sync()


func _setup_mixamo(f: Fighter) -> void:
	var model: Node3D = (load(scene_path(f.char_id)) as PackedScene).instantiate()
	add_child(model)
	var rig: Node3D = model.get_child(0)  # the scaled node that holds Skeleton3D
	_mesh = model.find_children("*", "MeshInstance3D", true, false)[0]
	_ap = AnimationPlayer.new()
	rig.add_child(_ap)  # root_node ".." -> tracks "Skeleton3D:mixamorig_*" resolve
	_ap.add_animation_library("", _with_aliases(_anims))
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
	_meshes = [_mesh]
	_build_weapon(rig, f.weapon, f.color)


## A humanoid body (VRoid / VRM, or Hunyuan 3D via hy_rig.py): scaled to fighter height, the
## shared clips retargeted onto its skeleton. `toon`: replace its materials with the game's
## character shader (texture, rim, flash, hair / coat sway from the flex colours); otherwise
## keep its own (MToon) materials and add the flash / rim overlay.
func _setup_humanoid(f: Fighter, path: String, toon: bool) -> void:
	_vrm = true
	var model: Node3D = (load(path) as PackedScene).instantiate()
	add_child(model)
	_sk = model.find_children("*", "Skeleton3D", true, false)[0]
	for m in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m)
	_mesh = _meshes[0]
	# height from the meshes, before any animation
	var top := 0.0
	for m in _meshes:
		var bb: AABB = m.mesh.get_aabb()
		top = maxf(top, (model.global_transform.affine_inverse() * m.global_transform * bb).end.y)
	model.scale = Vector3.ONE * (HEIGHT / maxf(top, 0.3))
	# size the body, not the hair: the head joint sits at the same height on every fighter, so a
	# tall mohawk or spiky hair doesn't shrink the person under it
	var head_b := _sk.find_bone("Head")
	if head_b >= 0:
		var head_y: float = (model.global_transform.affine_inverse() * (_sk.global_transform * _sk.get_bone_global_rest(head_b).origin)).y
		if head_y > 0.3:
			model.scale = Vector3.ONE * (HEIGHT * HEAD_AT / head_y)
	# the shared clips, moved onto this skeleton
	var ref_path: String = _anims.get_meta("ref", scene_path("kael"))
	var ref: Node3D = (load(ref_path) as PackedScene).instantiate() if ResourceLoader.exists(ref_path) else null
	var src: Skeleton3D = ref.find_children("*", "Skeleton3D", true, false)[0] if ref else null
	var lib := VrmRetarget.library(path + "|" + str(f.data.get("anim_set", "")), _anims, src, _sk) if src else _anims
	if ref:
		ref.free()
	_ap = AnimationPlayer.new()
	_sk.get_parent().add_child(_ap)   # root_node ".." -> tracks "<Skeleton>:Bone" resolve
	_ap.add_animation_library("", _with_aliases(lib))
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if toon:
		var src_mat := _mesh.get_active_material(0) as BaseMaterial3D
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_mat.set_shader_parameter("albedo_tex", src_mat.albedo_texture if src_mat else null)
		_mat.set_shader_parameter("use_flex", (_mesh.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0)
		_mat.set_shader_parameter("model_height", _mesh.mesh.get_aabb().size.y)
		_mat.set_shader_parameter("flash_color", f.color.lerp(Color.WHITE, 0.6))
		for m in _meshes:
			m.material_override = _mat
	else:
		# hit flash and a rim in the fighter's colour on top of the anime shading
		_overlay = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = OVERLAY
		_overlay.shader = sh
		_overlay.set_shader_parameter("color", f.color.lerp(Color.WHITE, 0.5))
		for m in _meshes:
			m.material_overlay = _overlay
	_build_weapon_vrm(f.weapon, f.color)


## The weapon in the right fist: the handle runs across the palm where the curled fingers
## close, the blade out of the thumb side.
func _build_weapon_vrm(kind: String, col: Color) -> void:
	var hand := _sk.find_bone("RightHand")
	var mid := _sk.find_bone("RightMiddleProximal")
	if hand < 0 or kind in ["gauntlets", ""]:
		return
	var w := _weapon_node(kind, col)
	if w == null:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "RightHand"
	_sk.add_child(att)
	att.add_child(w)
	var hb := _sk.get_bone_global_rest(hand)
	var want := Basis(Vector3.UP, Vector3.FORWARD * -1.0, Vector3.RIGHT)  # blade +Z (forward), edge up
	w.basis = hb.basis.orthonormalized().inverse() * want
	var grip := hb.origin
	if mid >= 0:
		var knuckle := _sk.get_bone_global_rest(mid).origin
		grip = hb.origin + (knuckle - hb.origin) * 0.75 + Vector3(0, -0.028, 0)
	w.position = hb.affine_inverse() * grip
	if bool(fighter.data.get("two_handed", false)) and _sk.find_bone("LeftHand") >= 0:
		_two_hands(w, float(fighter.data.get("grip_span", 0.12)))
	# fingers closed around the handle (rest pose: fingers along -X, palm down, thumb forward)
	for finger in ["Index", "Middle", "Ring", "Little"]:
		for k in 3:
			var b := _sk.find_bone("Right%s%s" % [finger, ["Proximal", "Intermediate", "Distal"][k]])
			if b >= 0:
				_grip.append([b, _curl(b, Vector3.BACK, CURL[k])])
	for k in 3:
		var tb := _sk.find_bone("RightThumb%s" % ["Metacarpal", "Proximal", "Distal"][k])
		if tb >= 0:
			_grip.append([tb, _curl(tb, Vector3.RIGHT, [10.0, 35.0, 30.0][k])])


## Both fists on the weapon: the right fist slides up toward the guard, the left closes below it
## (or further down a spear / axe haft), placed by two-bone IK every frame after the animation.
func _two_hands(w: Node3D, span: float) -> void:
	var up := w.basis.y.normalized()          # along the blade, in hand space
	w.position -= up * span * 0.3            # the right fist sits just under the guard
	_weapon = w
	_lgrip = Vector3(0.0, -span, 0.0)
	_two_handed = true
	_hold = 1.0
	_span = span
	# the weapon is placed every frame by _place_two_handed (skeleton space), not by the hand
	_w_hand_xf = w.transform
	w.get_parent().remove_child(w)
	_sk.add_child(w)


## Weapons are summoned for powers: fighters fight with fists and kicks, and when a power starts
## the weapon flashes into their hands in the fighter's colour, then dissolves when it ends.
func _summon(dt: float) -> void:
	if _wnode == null:
		return
	var want := fighter.state == Fighter.S.POWER
	var before := _wshow
	_wshow = move_toward(_wshow, 1.0 if want else 0.0, dt / (SUMMON_IN if want else SUMMON_OUT))
	if Vfx3D.on() and is_inside_tree():
		var at: Vector3 = (_tip.global_position + _wnode.global_position) * 0.5 if _tip else _wnode.global_position
		if before <= 0.0 and _wshow > 0.0:
			Vfx3D.flash(at, fighter.color, 5.0, 3.5, 0.3)
			Vfx3D.glow(at, 0.9, fighter.color, 3.0, 0.25, 1.8)
		elif before >= 1.0 and _wshow < 1.0:
			Vfx3D.particles(at, fighter.color, "sparks", 26, 0.6)
	_wnode.visible = _wshow > 0.001
	if not _two_handed:
		# keep the attachment's own scale (rigs scaled to fighter height) and grow from it
		if not _wnode.has_meta("s0"):
			_wnode.set_meta("s0", _wnode.basis.get_scale())
		var s0: Vector3 = _wnode.get_meta("s0")
		_wnode.basis = _wnode.basis.orthonormalized().scaled(s0 * maxf(_ease_w(), 0.001))


## Summon curve: a quick overshoot so the weapon snaps into the hands.
func _ease_w() -> float:
	var t := _wshow
	return maxf(0.001, 1.0 + 1.6 * pow(t - 1.0, 3.0) + 0.6 * pow(t - 1.0, 2.0)) if t > 0.0 else 0.001


## The body stands turned toward the camera (TURN) so the player sees it; the neck and head turn
## back so the eyes stay on the opponent. Applied after the animation, about the skeleton's up.
func _look_at_opponent() -> void:
	# the head turns back by however far the body is turned toward the camera right now
	var body_turn := absf(angle_difference(rotation.y, fighter.facing * PI / 2.0))
	var yaw := body_turn * LOOK * (1.0 if fighter.state != Fighter.S.KO else 0.0)
	for pair in [["Neck", 0.4], ["Head", 0.6]]:
		var b := _sk.find_bone(pair[0])
		if b < 0:
			continue
		var p := _sk.get_bone_parent(b)
		var pg := _sk.get_bone_global_pose(p).basis.get_rotation_quaternion() if p >= 0 else Quaternion.IDENTITY
		var g := pg * _sk.get_bone_pose_rotation(b)
		# turn away from the camera (+Z) toward the side the fighter faces
		var turn := Quaternion(Vector3.UP, yaw * float(fighter.facing) * float(pair[1]))
		_sk.set_bone_pose_rotation(b, (pg.inverse() * turn * g).normalized())


## Fist centre (inside the closed fingers) of one hand, in skeleton space.
func _fist(side: String) -> Vector3:
	var h := _sk.get_bone_global_pose(_sk.find_bone(side + "Hand")).origin
	var kb := _sk.find_bone(side + "MiddleProximal")
	if kb < 0:
		return h
	return h + (_sk.get_bone_global_pose(kb).origin - h) * 0.6


## Two-point grip: while both fists are on the weapon, its hilt runs through both fist centres
## (upper fist under the guard), turned about the hilt as the right hand turns. When the hands
## part (knockdowns, victory, some casts) it rides the right hand alone; the switch is blended.
func _place_two_handed(dt: float) -> void:
	var g_rh := _sk.get_bone_global_pose(_sk.find_bone("RightHand"))
	var one: Transform3D = g_rh * _w_hand_xf
	var r := _fist("Right")
	var l := _fist("Left")
	var apart := r.distance_to(l)
	var together := _hold > 0.5 and apart > 0.02 and apart < _span * 2.4
	_two_w = move_toward(_two_w, 1.0 if together else 0.0, dt * 10.0)
	var final := one
	if _two_w > 0.001:
		var blade := one.basis.y.normalized()
		var axis := (r - l).normalized()
		if axis.dot(blade) < 0.0:
			axis = -axis
		var upper := r if (r - l).dot(axis) >= 0.0 else l
		var b := Basis(_arc_q(blade, axis)) * one.basis
		var two := Transform3D(b, upper)
		final = one.interpolate_with(two, _two_w)
	_weapon.transform = final.scaled_local(Vector3.ONE * _ease_w())


## Two-bone IK for the left arm, run every frame right after the animation: the left fist closes
## on the weapon's grip below the right one. The elbow bends toward where the clip had it, so
## the clip's style is kept; `_hold` fades it out for hits, knockdowns and victory poses.
func _left_hand_ik() -> void:
	var ua := _sk.find_bone("LeftUpperArm")
	var la := _sk.find_bone("LeftLowerArm")
	var hd := _sk.find_bone("LeftHand")
	var rh := _sk.find_bone("RightHand")
	if ua < 0 or la < 0 or hd < 0 or rh < 0 or _hold <= 0.001:
		return
	var g_ua := _sk.get_bone_global_pose(ua)
	var g_la := _sk.get_bone_global_pose(la)
	var g_hd := _sk.get_bone_global_pose(hd)
	var g_rh := _sk.get_bone_global_pose(rh)
	# grip point in skeleton space (the weapon hangs off the right hand's attachment)
	var grip := g_rh * (_w_hand_xf * _lgrip)
	# aim the wrist so the fist's centre, not the wrist, lands on the grip
	var kn := _sk.find_bone("LeftMiddleProximal")
	var fist := (_sk.get_bone_global_pose(kn).origin - g_hd.origin) * 0.75 if kn >= 0 else Vector3.ZERO
	var t := grip - fist
	var a_pos := g_ua.origin
	var a := g_la.origin.distance_to(a_pos)
	var b := g_hd.origin.distance_to(g_la.origin)
	var to_t := t - a_pos
	var d := clampf(to_t.length(), absf(a - b) + 0.001, a + b - 0.001)
	var td := to_t.normalized()
	# elbow: in the plane of shoulder, target and the clip's own elbow
	var pole := g_la.origin - a_pos
	var perp := (pole - td * pole.dot(td))
	if perp.length() < 1e-4:
		perp = Vector3.DOWN - td * Vector3.DOWN.dot(td)
	perp = perp.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := a_pos + (td * cos_a + perp * sqrt(1.0 - cos_a * cos_a)) * a
	var q_ua := g_ua.basis.get_rotation_quaternion()
	var q_la := g_la.basis.get_rotation_quaternion()
	var r1 := _arc_q((g_la.origin - a_pos).normalized(), (elbow - a_pos).normalized())
	var n_ua := r1 * q_ua
	var lower_dir := r1 * (g_hd.origin - g_la.origin).normalized()
	var r2 := _arc_q(lower_dir, (a_pos + to_t.normalized() * d - elbow).normalized())
	var n_la := r2 * r1 * q_la
	var parent_q := _sk.get_bone_global_pose(_sk.get_bone_parent(ua)).basis.get_rotation_quaternion()
	var loc_ua := (parent_q.inverse() * n_ua).normalized()
	var loc_la := (n_ua.inverse() * n_la).normalized()
	_sk.set_bone_pose_rotation(ua, _sk.get_bone_pose_rotation(ua).slerp(loc_ua, _hold))
	_sk.set_bone_pose_rotation(la, _sk.get_bone_pose_rotation(la).slerp(loc_la, _hold))


static func _arc_q(a: Vector3, b: Vector3) -> Quaternion:
	var dd := clampf(a.dot(b), -1.0, 1.0)
	if dd > 0.99999:
		return Quaternion.IDENTITY
	var ax := a.cross(b)
	if ax.length() < 1e-6:
		ax = a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT)
	return Quaternion(ax.normalized(), acos(dd))


## Rest rotation of bone `b` turned by `deg` about a skeleton-space axis.
func _curl(b: int, axis: Vector3, deg: float) -> Quaternion:
	var gb := _sk.get_bone_global_rest(b).basis.orthonormalized()
	var local_axis := (gb.inverse() * axis).normalized()
	return _sk.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(local_axis, deg_to_rad(deg))


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
	var w := _weapon_node(kind, col)
	if w == null:
		return
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


## The weapon (designed GLB, or a stand-in built from boxes), with tip / mid markers set.
func _weapon_node(kind: String, col: Color) -> Node3D:
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
	var spec := _weapon_spec(fighter.char_id)
	var reach_override := -1.0
	if not spec.is_empty():
		reach_override = _glb_weapon(w, spec)
		kind = "glb"
	match kind:
		"glb":
			pass
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
			w.free()
			return null
	var reach: float = {"axe": 0.7, "spear": 1.37, "whip": 0.1, "daggers": 0.37}.get(kind, 0.92)
	if reach_override > 0.0:
		reach = reach_override
	_tip = Node3D.new()
	_tip.position = Vector3(0, reach, 0)
	w.add_child(_tip)
	_mid = Node3D.new()
	_mid.position = Vector3(0, reach * 0.45, 0)
	w.add_child(_mid)
	_wnode = w
	w.visible = false
	return w


## The designed weapon for this character, if its 3D model exists (see tools/models/weapon_grip.py).
static func _weapon_spec(char_id: String) -> Dictionary:
	if _weapon_specs.is_empty() and FileAccess.file_exists(WEAPONS_JSON):
		var data = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_JSON))
		if data is Dictionary:
			for wid in data:
				var sp: Dictionary = data[wid]
				if ResourceLoader.exists(sp.get("file", "")):
					_weapon_specs[sp.get("owner", "")] = sp
	return _weapon_specs.get(char_id, {})


## Put the weapon model under `w` with its grip at the origin, blade along +Y, edge along +X,
## scaled to its real length. Returns the grip-to-tip distance in metres.
static func _glb_weapon(w: Node3D, spec: Dictionary) -> float:
	var inst: Node3D = (load(spec["file"]) as PackedScene).instantiate()
	var axis := _v3(spec["axis"]).normalized()
	var side := _v3(spec["side"])
	side = (side - axis * side.dot(axis)).normalized()
	var src := Basis(side, axis, side.cross(axis))  # columns: where +X, +Y, +Z of the holder point
	var k: float = float(spec["metres"]) / float(spec["length"])
	var r := src.transposed().scaled(Vector3.ONE * k)
	inst.transform = Transform3D(r, -(r * _v3(spec["grip"])))
	w.add_child(inst)
	return float(spec["tip_from_grip"]) * k


static func _v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


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
	# the model faces +Z; +PI/2 turns it to face +X (screen right). Standing, the body is turned
	# toward the camera (three-quarter view); striking, being hit or blocking a hit it turns to
	# full profile, so fists and feet travel along the line between the fighters and land.
	var profile := fighter.state in [Fighter.S.ATTACK, Fighter.S.POWER, Fighter.S.HURT, Fighter.S.BLOCKSTUN,
		Fighter.S.KO, Fighter.S.DOWN]
	return fighter.facing * (PI / 2.0 - (0.0 if profile else TURN))


## Every clip also under "<name>~": restarting the same clip (a second hit, the same move again)
## crossfades from the alias instead of snapping back to its first frame.
static func _with_aliases(lib: AnimationLibrary) -> AnimationLibrary:
	for n in lib.get_animation_list():
		if not String(n).ends_with("~") and not lib.has_animation(String(n) + "~"):
			lib.add_animation(String(n) + "~", lib.get_animation(n))
	return lib


func _has(clip: String) -> bool:
	return _anims.has_animation(clip)


func _pick(clip: String) -> String:
	if _has(clip):
		return clip
	var fb: String = FALLBACK.get(clip, "idle")
	return fb if _has(fb) else "idle"


## [clip, time] for the current state; time < 0 means "play freely".
func _choose() -> Array:
	var f := fighter
	var t := f.state_time
	if f.get_meta("intro_run", false):
		return [_pick("run"), -1.0]
	match f.state:
		Fighter.S.IDLE, Fighter.S.FROZEN:
			return ["idle", -1.0]
		Fighter.S.WALK:
			return [_pick("walk_forward" if f.vel.x * f.facing >= 0.0 else "walk_back"), -1.0]
		Fighter.S.AIR:
			var j := _pick("jump")
			var s: float = _anims.get_animation(j).get_meta("strike", 0.5)
			return [j, minf(s - 0.1 + t, _anims.get_animation(j).length - 0.05)]
		Fighter.S.BLOCK:
			# a held guard: the block clip stopped at its guard-up frame (no pumping loop)
			var bl := _anims.get_animation("block")
			return ["block", minf(float(bl.get_meta("strike", 0.15)) + 0.12, bl.length * 0.5)]
		Fighter.S.BLOCKSTUN:
			# the jolt peaks just after the blocked hit, then settles back into the guard
			var bh := _pick("block_hit")
			var s2: float = _anims.get_animation(bh).get_meta("strike", 0.3)
			return [bh, minf(maxf(0.0, s2 - 0.05) + t * 1.3, _anims.get_animation(bh).length)]
		Fighter.S.HURT:
			var clip_h := "hit_heavy" if f.get_meta("hurt_heavy", false) else \
				("hit_light_2" if f.get_meta("hit_alt", false) and _has("hit_light_2") else "hit_light")
			clip_h = _pick(clip_h)
			var s3: float = _anims.get_animation(clip_h).get_meta("strike", 0.3)
			# the reaction starts just before its jolt, so the impact reads on the hit frame
			return [clip_h, minf(maxf(0.0, s3 - 0.12) + t * 1.15, _anims.get_animation(clip_h).length)]
		Fighter.S.DOWN:
			# knocked down: fall (the knockdown clip), lie, then the get-up
			if t < Fighter.DOWN_TIME:
				var kd := _pick("knockdown")
				var kl := _anims.get_animation(kd).length
				return [kd, minf(t * 1.6, kl * 0.7)]
			var gu := _pick("get_up")
			var gl := _anims.get_animation(gu).length
			var k := clampf((t - Fighter.DOWN_TIME) / Fighter.GETUP_TIME, 0.0, 1.0)
			return [gu, gl * (0.25 + 0.75 * k)]
		Fighter.S.KO:
			return [_pick("knockdown"), t]
		Fighter.S.WIN:
			return [_pick("victory"), t]
		Fighter.S.DASH:
			# one boxing step, forward or back, played across the dash
			var dc := _pick("walk_forward" if f.dash_dir > 0 else "walk_back")
			var dur: float = (Fighter.DASH_FWD if f.dash_dir > 0 else Fighter.DASH_BACK).y
			return [dc, _anims.get_animation(dc).length * clampf(t / dur, 0.0, 1.0)]
		Fighter.S.ATTACK:
			var clip := "air_attack"
			if f.move_kind == "light":
				clip = "light_%d" % (f.chain_index + 1)
			elif f.move_kind == "medium":
				clip = "heavy_%d" % (f.chain_index + 1)
			elif f.move_kind == "heavy":
				clip = "heavy_1"
			clip = _pick(clip)
			return [clip, _timeline(clip, t, f.move.get("startup", 0.1), f.move.get("active", 0.08), f.move.get("recovery", 0.2))]
		Fighter.S.POWER:
			var pd := f.power_def
			var want: String = POWER_CLIP.get(pd.get("type", ""), "cast_1")
			if pd.get("type", "") == "dash" and _has("dash"):
				want = "dash"
			if f.power_index == 2 and _has("ultimate"):
				want = "ultimate"
			var pc := _pick(want)
			return [pc, _timeline(pc, t, pd.get("startup", 0.2), pd.get("active", 0.1), pd.get("recovery", 0.3))]
	return ["idle", -1.0]


## Map game time in a move to clip time so the clip's strike lands on the move's active frame.
## The wind-up is the clip's last stretch before the strike, played at most MAX_WIND_SPEED, the
## recovery at most MAX_RECOVER_SPEED: the move reads as a move, not a flicker between poses.
func _timeline(clip: String, t: float, su: float, ac: float, re: float) -> float:
	var a := _anims.get_animation(clip)
	var s: float = a.get_meta("strike", a.length * 0.4)
	var wind := minf(s, maxf(su, 0.01) * MAX_WIND_SPEED)
	var follow := clampf(a.length - s - 0.08, 0.0, maxf(re, 0.01) * MAX_RECOVER_SPEED)
	if t < su:
		return s - wind + wind * (t / maxf(su, 0.001))
	if t < su + ac:
		return s + 0.08 * ((t - su) / maxf(ac, 0.001))
	return minf(s + 0.08 + follow * ((t - su - ac) / maxf(re, 0.001)), a.length)


## Where the striking hand or foot of the current attack is, in fight (2D logic) pixels; the hit
## spark goes there. Empty when there is no skeleton or attack clip.
func strike_point_2d() -> Array:
	if _sk == null or fighter == null:
		return []
	var base := _clip.trim_suffix("~")
	if base == "" or not _has(base):
		return []
	var limb: String = _anims.get_animation(base).get_meta("strike_bone", "right_hand")
	var bname: String = {"right_hand": "RightHand", "left_hand": "LeftHand", "right_foot": "RightFoot",
		"left_foot": "LeftFoot"}.get(limb, "RightHand")
	var b := _sk.find_bone(bname)
	if b < 0:
		return []
	return [stage.to_logic(_sk.global_transform * _sk.get_bone_global_pose(b).origin)]


func sync() -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	var dt := get_process_delta_time()
	if dt <= 0.0:
		dt = 1.0 / 60.0
	_t += dt
	position = stage.to_world(fighter.render_position())
	if fighter.hitstop > 0.0:
		# impact: the body holds, with a small shake on the one that was hit
		if fighter.state in [Fighter.S.HURT, Fighter.S.BLOCKSTUN, Fighter.S.DOWN]:
			position.x += sin(_t * 90.0) * 0.012
	_yaw = lerp_angle(_yaw, _target_yaw(), 1.0 - exp(-dt * 22.0))
	rotation.y = _yaw
	_animate(dt)
	var flash := clampf(fighter.flash, 0.0, 1.0) * 0.45
	if fighter.state == Fighter.S.ATTACK and fighter.move_kind == "heavy" \
			and fighter.state_time < float(fighter.move.get("startup", 0.36)):
		flash = maxf(flash, 0.18 + 0.14 * sin(_t * 40.0))   # a heavy's wind-up glows: it can be seen coming
	if _vrm:
		for g in _grip:
			_sk.set_bone_pose_rotation(g[0], g[1])
	if _vrm:
		_look_at_opponent()
	_summon(dt)
	if _two_handed:
		# both hands on the weapon only while it is summoned for a power
		var hold := _wshow > 0.5 and not (fighter.state in [Fighter.S.HURT, Fighter.S.KO, Fighter.S.WIN])
		_hold = move_toward(_hold, 1.0 if hold else 0.0, dt * 6.0)
		_left_hand_ik()
		_place_two_handed(dt)
	if _overlay:
		_overlay.set_shader_parameter("flash", flash)
	else:
		_secondary(dt)
		_mat.set_shader_parameter("flash", flash)
	for m in _meshes:
		m.transparency = 1.0 - fighter.modulate.a


## Drive the AnimationPlayer by hand. Clip time follows the fight logic exactly (time-mapped
## moves), while crossfades always run in real time: the clip is placed one frame before its
## target and then advanced by the real frame time, so a switch blends over ACTION_BLEND seconds
## however fast the move's clip time runs.
func _animate(dt: float) -> void:
	var pick := _choose()
	var clip: String = pick[0]
	var time: float = pick[1]
	var serial: int = fighter.state_serial
	var restart := serial != _serial and time >= 0.0
	_serial = serial
	_last_state = fighter.state
	var length := _anims.get_animation(clip).length
	var current := _clip.trim_suffix("~")
	if clip != current or restart:
		var name := clip
		if clip == current:
			_alt = not _alt   # the same clip again: switch to its alias so it crossfades
			name = clip + "~" if _alt else clip
		else:
			_alt = false
		_ap.play(name, BLEND.get(clip, ACTION_BLEND))
		_clip = name
		if time >= 0.0:
			_ap.seek(maxf(0.0, clampf(time, 0.0, length) - dt), false)
	if fighter.hitstop > 0.0:
		return   # hit-stop: both bodies hold the impact pose
	if time < 0.0:
		var rate := 1.0
		if fighter.get_meta("intro_run", false):
			rate = float(fighter.get_meta("run_rate", 1.0))
		elif fighter.state == Fighter.S.WALK:
			rate = clampf(absf(fighter.vel.x) / maxf(fighter.walk_speed, 1.0), 0.6, 1.5)
		_ap.advance(dt * rate)
	else:
		var target := clampf(time, 0.0, length)
		if target >= dt:
			_ap.seek(target - dt, false)
			_ap.advance(dt)
		else:
			_ap.seek(0.0, false)
			_ap.advance(target)


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
