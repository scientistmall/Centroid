class_name AiClips
extends RefCounted
## Clips made by the HY-Motion text-to-motion model (tools/models/kaggle/motion/motion.py,
## tools/models/motion_to_json.py): builds their source skeleton (SMPL-H body joints, T-pose,
## bones named "smpl_<joint>") and an Animation per clip, ready for VrmRetarget like Mixamo clips.

## The source skeleton from <dir>/skeleton.json (kept for the caller to free).
static func skeleton(dir: String) -> Skeleton3D:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/skeleton.json"))
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	var names: Array = d["names"]
	var rest: Array = d["rest"]
	var parents: Array = d["parents"]
	for i in names.size():
		sk.add_bone("smpl_" + str(names[i]))
	for i in names.size():
		var p := int(parents[i])
		var pos := Vector3(rest[i][0], rest[i][1], rest[i][2])
		if p >= 0:
			sk.set_bone_parent(i, p)
			pos -= Vector3(rest[p][0], rest[p][1], rest[p][2])
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, pos))
	sk.reset_bone_poses()
	return sk


## One clip from <slot>_k<i>.json: rotation tracks for every joint, pelvis position track.
static func animation(path: String, sk: Skeleton3D) -> Animation:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var fps := float(d.get("fps", 30))
	var quats: Array = d["quats"]
	var pel: Array = d["pelvis"]
	var a := Animation.new()
	a.length = (quats.size() - 1) / fps
	for j in sk.get_bone_count():
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:" + sk.get_bone_name(j)))
		for f in quats.size():
			var q: Array = quats[f][j]
			a.rotation_track_insert_key(t, f / fps, Quaternion(q[0], q[1], q[2], q[3]).normalized())
	var tp := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(tp, NodePath("Skeleton3D:" + sk.get_bone_name(0)))
	for f in pel.size():
		a.position_track_insert_key(tp, f / fps, Vector3(pel[f][0], pel[f][1], pel[f][2]))
	a.set_meta("prompt", d.get("prompt", ""))
	return a
