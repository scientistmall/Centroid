extends SceneTree
## Build the shared animation library from the Mixamo clips in assets/animations/*.fbx,
## or a fighting style's set from assets/animations/<set>/*.fbx (see tools/models/anim_sets.py):
##   godot --headless --path . -s tools/models/build_anims.gd [-- <set> ...]
## - one Animation per file, named after the file (idle, light_1, ...)
## - hips X/Z travel removed (the game moves fighters itself); vertical motion kept
## - looping set for idle / walk / block
## Output: assets/animations/centroid_anims.res (AnimationLibrary)

const LOOP := ["idle", "walk_forward", "walk_back", "block", "run"]
const OUT := "res://assets/animations/centroid_anims.res"


func _init() -> void:
	var sets := OS.get_cmdline_user_args()
	if sets.is_empty():
		_build("res://assets/animations", OUT, "res://assets/characters/kael/kael.tscn")
	for s in sets:
		var dir := "res://assets/animations/%s" % s
		_build(dir, "%s/%s_anims.res" % [dir, s], dir + "/idle.fbx")
	quit()


## `ref`: a scene whose skeleton the clips were made on (strike timing, and retargeting in game).
func _build(dir: String, out: String, ref: String) -> void:
	if _ref:
		_ref.free()
	_ref = null
	_sk = null
	_ref_path = ref
	var lib := AnimationLibrary.new()
	var d := DirAccess.open(dir)
	var names := []
	for f in d.get_files():
		if not f.ends_with(".fbx"):
			continue
		var clip := f.get_basename()
		var root: Node = (load(dir + "/" + f) as PackedScene).instantiate()
		var aps := root.find_children("*", "AnimationPlayer", true, false)
		if aps.is_empty():
			push_warning("no animation in " + f)
			root.free()
			continue
		var ap: AnimationPlayer = aps[0]
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with("mixamorig_Hips"):
				var p0: Vector3 = a.track_get_key_value(t, 0)
				for k in a.track_get_key_count(t):
					var p: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Vector3(p0.x, p.y, p0.z))
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOP else Animation.LOOP_NONE
		var strike := _strike_time(a)
		a.set_meta("strike", strike)
		lib.add_animation(clip, a)
		names.append("%s (%.2fs, strike %.2fs)" % [clip, a.length, strike])
		root.free()
	# "reverse:<clip>" slots (set.txt): the clip played backwards, e.g. walking back
	if FileAccess.file_exists(dir + "/set.txt"):
		for line in FileAccess.get_file_as_string(dir + "/set.txt").split("\n"):
			var kv := line.split("=", true, 1)
			if kv.size() == 2 and kv[1].begins_with("reverse:") and lib.has_animation(kv[1].substr(8)):
				var rev := _reversed(lib.get_animation(kv[1].substr(8)))
				lib.add_animation(kv[0], rev)
				names.append("%s (reverse of %s)" % [kv[0], kv[1].substr(8)])
	lib.set_meta("ref", ref)
	ResourceSaver.save(lib, out)
	print("ANIMS %d clips -> %s:\n  %s" % [names.size(), out, "\n  ".join(names)])


## The same motion played backwards (a walk becomes a walk back).
func _reversed(a: Animation) -> Animation:
	var r := a.duplicate(true) as Animation
	for t in r.get_track_count():
		var keys := []
		for k in a.track_get_key_count(t):
			keys.append([a.length - a.track_get_key_time(t, k), a.track_get_key_value(t, k)])
		for k in range(r.track_get_key_count(t) - 1, -1, -1):
			r.track_remove_key(t, k)
		for kv in keys:
			r.track_insert_key(t, kv[0], kv[1])
	return r


var _ref: Node
var _sk: Skeleton3D
var _ref_path := ""


## The strike moment: when the fastest hand or foot peaks (ignoring the first 15% wind-up),
## measured on Kael's skeleton. The game lines this frame up with a move's hit frame.
func _strike_time(a: Animation) -> float:
	if _sk == null:
		_ref = (load(_ref_path) as PackedScene).instantiate()
		_sk = _ref.find_children("*", "Skeleton3D", true, false)[0]
	var limbs := ["mixamorig_RightHand", "mixamorig_LeftHand", "mixamorig_RightFoot", "mixamorig_LeftFoot"]
	var ids := limbs.map(func(b): return _sk.find_bone(b))
	var dt := 1.0 / 30.0
	var prev := []
	var best := 0.0
	var best_t := a.length * 0.5
	var t := 0.0
	while t <= a.length:
		for tr in a.get_track_count():
			var bone := _sk.find_bone(String(a.track_get_path(tr)).get_slice(":", 1))
			if bone < 0:
				continue
			match a.track_get_type(tr):
				Animation.TYPE_ROTATION_3D:
					_sk.set_bone_pose_rotation(bone, a.rotation_track_interpolate(tr, t))
				Animation.TYPE_POSITION_3D:
					_sk.set_bone_pose_position(bone, a.position_track_interpolate(tr, t))
		var now := []
		for i in ids:
			now.append(_global(i).origin)
		if not prev.is_empty() and t > a.length * 0.15:
			for k in now.size():
				var sp: float = (now[k] - prev[k]).length() / dt
				if sp > best:
					best = sp
					best_t = t
		prev = now
		t += dt
	return best_t


## Forward kinematics by hand (the skeleton isn't in a scene tree, so it never updates itself).
func _global(bone: int) -> Transform3D:
	var xf := Transform3D(Basis(_sk.get_bone_pose_rotation(bone)).scaled(_sk.get_bone_pose_scale(bone)),
						  _sk.get_bone_pose_position(bone))
	var p := _sk.get_bone_parent(bone)
	return _global(p) * xf if p >= 0 else xf
