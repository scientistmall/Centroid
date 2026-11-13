extends SceneTree
## Build the shared animation library from the Mixamo clips in assets/animations/*.fbx.
##   godot --headless --path . -s tools/models/build_anims.gd
## - one Animation per file, named after the file (idle, light_1, ...)
## - hips X/Z travel removed (the game moves fighters itself); vertical motion kept
## - looping set for idle / walk / block
## Output: assets/animations/centroid_anims.res (AnimationLibrary)

const LOOP := ["idle", "walk_forward", "walk_back", "block"]
const OUT := "res://assets/animations/centroid_anims.res"


func _init() -> void:
	var lib := AnimationLibrary.new()
	var d := DirAccess.open("res://assets/animations")
	var names := []
	for f in d.get_files():
		if not f.ends_with(".fbx"):
			continue
		var clip := f.get_basename()
		var root: Node = (load("res://assets/animations/" + f) as PackedScene).instantiate()
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
	ResourceSaver.save(lib, OUT)
	print("ANIMS %d clips -> %s:\n  %s" % [names.size(), OUT, "\n  ".join(names)])
	if _ref:
		_ref.free()
	quit()


var _ref: Node
var _sk: Skeleton3D


## The strike moment: when the fastest hand or foot peaks (ignoring the first 15% wind-up),
## measured on Kael's skeleton. The game lines this frame up with a move's hit frame.
func _strike_time(a: Animation) -> float:
	if _sk == null:
		_ref = (load("res://assets/characters/kael/kael.tscn") as PackedScene).instantiate()
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
