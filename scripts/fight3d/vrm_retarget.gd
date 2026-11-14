class_name VrmRetarget
extends RefCounted
## Moves the shared Mixamo fight clips (centroid_anims.res) onto a VRM humanoid skeleton,
## at load time, for any VRM the player's characters are built from (VRoid Studio exports).
##
## Per frame, each source bone's motion is taken as a rotation away from its rest pose in
## skeleton space ("delta"). The target bone gets the same delta, applied after aligning its
## rest direction with the source's (the rigs rest in different poses: A-pose vs T-pose), so
## arms, legs and fingers point where the source's point. Hips height is scaled to the body.

const MIXAMO := {
	"Hips": "Hips", "Spine": "Spine", "Spine1": "Chest", "Spine2": "UpperChest", "Neck": "Neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftArm": "LeftUpperArm", "LeftForeArm": "LeftLowerArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightArm": "RightUpperArm", "RightForeArm": "RightLowerArm", "RightHand": "RightHand",
	"LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToes",
	"RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToes",
	"LeftHandThumb1": "LeftThumbMetacarpal", "LeftHandThumb2": "LeftThumbProximal", "LeftHandThumb3": "LeftThumbDistal",
	"LeftHandIndex1": "LeftIndexProximal", "LeftHandIndex2": "LeftIndexIntermediate", "LeftHandIndex3": "LeftIndexDistal",
	"LeftHandMiddle1": "LeftMiddleProximal", "LeftHandMiddle2": "LeftMiddleIntermediate", "LeftHandMiddle3": "LeftMiddleDistal",
	"LeftHandRing1": "LeftRingProximal", "LeftHandRing2": "LeftRingIntermediate", "LeftHandRing3": "LeftRingDistal",
	"LeftHandPinky1": "LeftLittleProximal", "LeftHandPinky2": "LeftLittleIntermediate", "LeftHandPinky3": "LeftLittleDistal",
	"RightHandThumb1": "RightThumbMetacarpal", "RightHandThumb2": "RightThumbProximal", "RightHandThumb3": "RightThumbDistal",
	"RightHandIndex1": "RightIndexProximal", "RightHandIndex2": "RightIndexIntermediate", "RightHandIndex3": "RightIndexDistal",
	"RightHandMiddle1": "RightMiddleProximal", "RightHandMiddle2": "RightMiddleIntermediate", "RightHandMiddle3": "RightMiddleDistal",
	"RightHandRing1": "RightRingProximal", "RightHandRing2": "RightRingIntermediate", "RightHandRing3": "RightRingDistal",
	"RightHandPinky1": "RightLittleProximal", "RightHandPinky2": "RightLittleIntermediate", "RightHandPinky3": "RightLittleDistal",
}
## Where each humanoid bone points (its child), for aligning rest directions. Torso bones are
## left unaligned so the spine doesn't twist.
const AIM := {
	"LeftShoulder": "LeftUpperArm", "LeftUpperArm": "LeftLowerArm", "LeftLowerArm": "LeftHand", "LeftHand": "LeftMiddleProximal",
	"RightShoulder": "RightUpperArm", "RightUpperArm": "RightLowerArm", "RightLowerArm": "RightHand", "RightHand": "RightMiddleProximal",
	"LeftUpperLeg": "LeftLowerLeg", "LeftLowerLeg": "LeftFoot", "LeftFoot": "LeftToes",
	"RightUpperLeg": "RightLowerLeg", "RightLowerLeg": "RightFoot", "RightFoot": "RightToes",
	"LeftThumbMetacarpal": "LeftThumbProximal", "LeftThumbProximal": "LeftThumbDistal",
	"LeftIndexProximal": "LeftIndexIntermediate", "LeftIndexIntermediate": "LeftIndexDistal",
	"LeftMiddleProximal": "LeftMiddleIntermediate", "LeftMiddleIntermediate": "LeftMiddleDistal",
	"LeftRingProximal": "LeftRingIntermediate", "LeftRingIntermediate": "LeftRingDistal",
	"LeftLittleProximal": "LeftLittleIntermediate", "LeftLittleIntermediate": "LeftLittleDistal",
	"RightThumbMetacarpal": "RightThumbProximal", "RightThumbProximal": "RightThumbDistal",
	"RightIndexProximal": "RightIndexIntermediate", "RightIndexIntermediate": "RightIndexDistal",
	"RightMiddleProximal": "RightMiddleIntermediate", "RightMiddleIntermediate": "RightMiddleDistal",
	"RightRingProximal": "RightRingIntermediate", "RightRingIntermediate": "RightRingDistal",
	"RightLittleProximal": "RightLittleIntermediate", "RightLittleIntermediate": "RightLittleDistal",
}
const FPS := 30.0

static var _cache: Dictionary = {}


## The shared library retargeted onto `dst` (cached per `key`, normally the VRM path).
## Track paths are "<skeleton node name>:<bone>", relative to the skeleton's parent.
static func library(key: String, src_lib: AnimationLibrary, src: Skeleton3D, dst: Skeleton3D) -> AnimationLibrary:
	if _cache.has(key):
		return _cache[key]
	var out := AnimationLibrary.new()
	var plan := _plan(src, dst)
	for clip in src_lib.get_animation_list():
		out.add_animation(clip, _convert(src_lib.get_animation(clip), src, dst, plan))
	_cache[key] = out
	return out


static func _humanoid(src_bone: String) -> String:
	return MIXAMO.get(src_bone.trim_prefix("mixamorig_").trim_prefix("mixamorig:"), "")


## Per target bone: its source bone, and the rest-alignment rotation.
static func _plan(src: Skeleton3D, dst: Skeleton3D) -> Dictionary:
	var by_target := {}
	for i in src.get_bone_count():
		var h := _humanoid(src.get_bone_name(i))
		if h != "" and dst.find_bone(h) >= 0:
			by_target[h] = i
	# a target without UpperChest takes the top of the source spine on Chest
	if dst.find_bone("UpperChest") < 0 and dst.find_bone("Chest") >= 0:
		var s2 := _find_src(src, "Spine2")
		if s2 >= 0:
			by_target["Chest"] = s2
	var align := {}
	for h in by_target:
		align[h] = Quaternion.IDENTITY
		var child: String = AIM.get(h, "")
		if child == "" or not by_target.has(child):
			continue
		var t0 := dst.get_bone_global_rest(dst.find_bone(h)).origin
		var t1 := dst.get_bone_global_rest(dst.find_bone(child)).origin
		var s0 := src.get_bone_global_rest(by_target[h]).origin
		var s1 := src.get_bone_global_rest(by_target[child]).origin
		var dt := (t1 - t0).normalized()
		var ds := (s1 - s0).normalized()
		if dt.length() > 0.5 and ds.length() > 0.5:
			align[h] = _arc(dt, ds)
	return {"src_of": by_target, "align": align}


static func _find_src(src: Skeleton3D, short: String) -> int:
	for i in src.get_bone_count():
		if src.get_bone_name(i).trim_prefix("mixamorig_").trim_prefix("mixamorig:") == short:
			return i
	return -1


## Shortest rotation taking direction a onto b.
static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	var d := clampf(a.dot(b), -1.0, 1.0)
	if d > 0.99999:
		return Quaternion.IDENTITY
	var axis := a.cross(b)
	if axis.length() < 1e-6:
		axis = a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT)
	return Quaternion(axis.normalized(), acos(d))


static func _convert(a: Animation, src: Skeleton3D, dst: Skeleton3D, plan: Dictionary) -> Animation:
	var n_src := src.get_bone_count()
	var n_dst := dst.get_bone_count()
	# source tracks by bone
	var rot_track := {}
	var hips_pos := -1
	var src_hips := _find_src(src, "Hips")
	for t in a.get_track_count():
		var bone := src.find_bone(String(a.track_get_path(t).get_concatenated_subnames()))
		if bone < 0:
			continue
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot_track[bone] = t
		elif a.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == src_hips:
			hips_pos = t
	var src_of: Dictionary = plan["src_of"]
	var align: Dictionary = plan["align"]
	# rests
	var s_rest_g: Array[Quaternion] = []
	for i in n_src:
		s_rest_g.append(src.get_bone_global_rest(i).basis.get_rotation_quaternion())
	var d_rest_g: Array[Quaternion] = []
	var d_rest_l: Array[Quaternion] = []
	for j in n_dst:
		d_rest_g.append(dst.get_bone_global_rest(j).basis.get_rotation_quaternion())
		d_rest_l.append(dst.get_bone_rest(j).basis.get_rotation_quaternion())
	var targets: Array[int] = []
	for j in n_dst:
		if src_of.has(dst.get_bone_name(j)):
			targets.append(j)
	var out := Animation.new()
	out.length = a.length
	out.loop_mode = a.loop_mode
	for m in a.get_meta_list():
		out.set_meta(m, a.get_meta(m))
	var skel := String(dst.name)
	var tr := {}
	for j in targets:
		var t := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(t, NodePath("%s:%s" % [skel, dst.get_bone_name(j)]))
		tr[j] = t
	var d_hips := dst.find_bone("Hips")
	var hp := -1
	var ratio := 1.0
	if hips_pos >= 0 and d_hips >= 0 and src_hips >= 0:
		hp = out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(hp, NodePath("%s:Hips" % skel))
		ratio = dst.get_bone_global_rest(d_hips).origin.y / maxf(src.get_bone_global_rest(src_hips).origin.y, 1e-6)
	var frames := maxi(1, int(ceil(a.length * FPS)))
	var s_glob: Array[Quaternion] = []
	s_glob.resize(n_src)
	var d_glob: Array[Quaternion] = []
	d_glob.resize(n_dst)
	for f in frames + 1:
		var time := minf(f / FPS, a.length)
		# source forward kinematics (rotations only)
		for i in n_src:
			var lq: Quaternion = a.rotation_track_interpolate(rot_track[i], time) if rot_track.has(i) else src.get_bone_rest(i).basis.get_rotation_quaternion()
			var p := src.get_bone_parent(i)
			s_glob[i] = (s_glob[p] * lq) if p >= 0 else lq
		# target, parents first (bones are stored parent-before-child)
		for j in n_dst:
			var p2 := dst.get_bone_parent(j)
			var pg: Quaternion = d_glob[p2] if p2 >= 0 else Quaternion.IDENTITY
			var name := dst.get_bone_name(j)
			if src_of.has(name):
				var si: int = src_of[name]
				var delta: Quaternion = s_glob[si] * s_rest_g[si].inverse()
				var g: Quaternion = delta * (align[name] as Quaternion) * d_rest_g[j]
				d_glob[j] = g
				out.rotation_track_insert_key(tr[j], time, (pg.inverse() * g).normalized())
			else:
				d_glob[j] = pg * d_rest_l[j]
		if hp >= 0:
			var sp: Vector3 = a.position_track_interpolate(hips_pos, time)
			var s0 := src.get_bone_rest(src_hips).origin
			var sparent := src.get_bone_parent(src_hips)
			var to_skel := src.get_bone_global_rest(sparent).basis if sparent >= 0 else Basis()
			var delta_p := to_skel * (sp - s0) * ratio
			var dparent := dst.get_bone_parent(d_hips)
			var to_parent := dst.get_bone_global_rest(dparent).basis.inverse() if dparent >= 0 else Basis()
			out.position_track_insert_key(hp, time, dst.get_bone_rest(d_hips).origin + to_parent * delta_p)
	return out
