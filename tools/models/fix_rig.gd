extends SceneTree
## Fix Mixamo skin weights on an AI-generated character and save a game-ready scene.
##
##   godot --headless --path . -s tools/models/fix_rig.gd -- kael [rhex mira ...]
##
## AI meshes are one continuous surface (scarf/collar touching the jaw, fused fingers), so
## Mixamo's auto-rig blends the face between Head and Neck and smears the hands. This:
##   * makes everything above the jaw line move 100% with the Head bone (short blend band),
##   * makes everything past the wrist move 100% with the Hand bone,
## but only for vertices Mixamo already gave mostly to those regions (coats, scarf tails and
## long hair keep their weights). Output: assets/characters/<name>/<name>.tscn (+ _mesh.res),
## scaled to the character's real height, plus a weights report.

const HEIGHTS := {
	"kael": 1.78, "tala": 1.75, "mira": 1.62, "darin": 1.90, "iren": 1.72, "lyra": 1.66, "oren": 1.74,
	"auren": 1.80, "seran": 1.78, "rhex": 1.88, "vaska": 1.65, "mael": 1.85, "nyra": 1.72,
	"zerin": 1.76, "corvin": 1.83, "thane": 1.86, "veyr": 1.85,
}
const JAW := 0.40         # jaw line: this fraction of the way from Head down to Neck
const BAND := 0.012       # head blend band, fraction of body height
const HEAD_R := 0.095     # max horizontal distance from the head axis, fraction of body height
const HAND_REACH := 0.13  # max distance from the wrist, fraction of body height


func _init() -> void:
	var names := OS.get_cmdline_user_args()
	var ok := true
	for n in names:
		ok = _fix(n) and ok
	quit(0 if ok else 1)


func _fix(name: String) -> bool:
	var src := "res://assets/characters/%s/%s.fbx" % [name, name]
	var ps: PackedScene = load(src)
	if ps == null:
		push_error("cannot load " + src)
		return false
	var root: Node3D = ps.instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var skin: Skin = mi.skin
	# bone name -> skin bind index, and bind-space position of each bone
	var bind_of := {}
	var bpos := {}
	for b in skin.get_bind_count():
		var bn := skin.get_bind_name(b)
		if bn == "":
			bn = sk.get_bone_name(skin.get_bind_bone(b))
		bind_of[bn] = b
		bpos[bn] = skin.get_bind_pose(b).affine_inverse().origin
	var need := ["mixamorig_Head", "mixamorig_Neck", "mixamorig_LeftHand", "mixamorig_RightHand",
				 "mixamorig_LeftForeArm", "mixamorig_RightForeArm"]
	for k in need:
		if not bind_of.has(k):
			push_error("%s: bone %s not in skin" % [name, k])
			return false

	var arrays := mi.mesh.surface_get_arrays(0)
	var mat := mi.mesh.surface_get_material(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var nb := bones.size() / verts.size()
	var aabb := mi.mesh.get_aabb()
	var H := aabb.size.y

	var head_b: int = bind_of["mixamorig_Head"]
	var neck_b: int = bind_of["mixamorig_Neck"]
	var top_b: int = bind_of.get("mixamorig_HeadTop_End", head_b)
	var head_p: Vector3 = bpos["mixamorig_Head"]
	var neck_p: Vector3 = bpos["mixamorig_Neck"]
	var cut := head_p.y - JAW * (head_p.y - neck_p.y)
	var band := BAND * H
	var head_set := [head_b, neck_b, top_b]

	var sides := []
	for s in ["Left", "Right"]:
		var hand_b: int = bind_of["mixamorig_%sHand" % s]
		var fore_b: int = bind_of["mixamorig_%sForeArm" % s]
		var wrist: Vector3 = bpos["mixamorig_%sHand" % s]
		var elbow: Vector3 = bpos["mixamorig_%sForeArm" % s]
		sides.append({"hand": hand_b, "fore": fore_b, "wrist": wrist, "axis": (wrist - elbow).normalized()})

	var n_head := 0
	var n_hand := 0
	for v in verts.size():
		var p := verts[v]
		var o := v * nb
		# --- head
		var hw := 0.0
		for k in nb:
			if bones[o + k] in head_set:
				hw += weights[o + k]
		var horiz := Vector2(p.x - head_p.x, p.z - head_p.z).length()
		if hw >= 0.5 and horiz < HEAD_R * H and p.y > cut - band:
			var t := clampf((p.y - (cut - band)) / band, 0.0, 1.0)
			_blend_to(bones, weights, o, nb, head_b, t)
			n_head += 1
			continue
		# --- hands
		for sd in sides:
			var aw := 0.0
			for k in nb:
				if bones[o + k] == sd["hand"] or bones[o + k] == sd["fore"]:
					aw += weights[o + k]
			if aw < 0.5:
				continue
			var d: Vector3 = p - sd["wrist"]
			if d.length() > HAND_REACH * H:
				continue
			var along := d.dot(sd["axis"])
			if along > -0.004 * H:
				var t2 := clampf((along + 0.004 * H) / (0.008 * H), 0.0, 1.0)
				_blend_to(bones, weights, o, nb, sd["hand"], t2)
				n_hand += 1
				break

	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_COLOR] = _flex_mask(verts, bones, weights, nb, bind_of, bpos, H)
	var am := ArrayMesh.new()
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nb == 8 else 0
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	am.surface_set_material(0, mat)
	var mesh_path := "res://assets/characters/%s/%s_mesh.res" % [name, name]
	ResourceSaver.save(am, mesh_path)
	am = load(mesh_path)
	mi.mesh = am

	# scene: real height, feet on the ground; keep the AnimationPlayer out (clips come from the shared library)
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var target: float = HEIGHTS.get(name, 1.8)
	var s := target / H
	root.scale = Vector3.ONE * s
	root.position = Vector3(0, -aabb.position.y * s, 0)
	root.name = name
	# save as plain nodes, not as an instance of the FBX (an instance would keep the FBX's mesh)
	root.scene_file_path = ""
	mi.skin = skin.duplicate()
	var wrapper := Node3D.new()
	wrapper.name = name.capitalize()
	wrapper.add_child(root)
	_own(root, wrapper)
	var packed := PackedScene.new()
	packed.pack(wrapper)
	var out := "res://assets/characters/%s/%s.tscn" % [name, name]
	ResourceSaver.save(packed, out)
	print("RIGFIX %s: verts=%d head=%d hand=%d height=%.2fm scale=%.2f -> %s" % [name, verts.size(), n_head, n_hand, target, s, out])
	wrapper.free()
	return true


## Secondary-motion mask in vertex colour, read by assets/shaders/character.gdshader:
##   R = cloth flex: below the hips and not bound to the legs (coat tails, skirts, capes),
##       or hanging well away from the leg bones; grows toward the hem.
##   G = hair flex: head-bound vertices away from the scalp (spikes, long hair).
static func _flex_mask(verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, nb: int,
		bind_of: Dictionary, bpos: Dictionary, H: float) -> PackedColorArray:
	var cols := PackedColorArray()
	cols.resize(verts.size())
	var legs := []
	var segs := []
	for s in ["Left", "Right"]:
		for b in ["UpLeg", "Leg", "Foot", "ToeBase"]:
			var key := "mixamorig_%s%s" % [s, b]
			if bind_of.has(key):
				legs.append(bind_of[key])
		if bpos.has("mixamorig_%sUpLeg" % s) and bpos.has("mixamorig_%sFoot" % s):
			segs.append([bpos["mixamorig_%sUpLeg" % s], bpos["mixamorig_%sLeg" % s], bpos["mixamorig_%sFoot" % s]])
	var head_set := []
	for k in ["mixamorig_Head", "mixamorig_HeadTop_End"]:
		if bind_of.has(k):
			head_set.append(bind_of[k])
	var hips_y: float = bpos.get("mixamorig_Hips", Vector3(0, H * 0.5, 0)).y
	var head_c: Vector3 = (bpos["mixamorig_Head"] + bpos.get("mixamorig_HeadTop_End", bpos["mixamorig_Head"])) * 0.5
	for v in verts.size():
		var p := verts[v]
		var o := v * nb
		var legw := 0.0
		var headw := 0.0
		for k in nb:
			if bones[o + k] in legs:
				legw += weights[o + k]
			elif bones[o + k] in head_set:
				headw += weights[o + k]
		var cloth := 0.0
		var top := hips_y - 0.03 * H
		if p.y < top:
			var depth := clampf((top - p.y) / (0.38 * H), 0.0, 1.0)
			cloth = depth * (1.0 - legw)
			if p.y < 0.09 * H and legw > 0.3:
				cloth = 0.0
			var dmin := 1e9
			for sg in segs:
				dmin = minf(dmin, minf(_seg_dist(p, sg[0], sg[1]), _seg_dist(p, sg[1], sg[2])))
			# (not near the floor: toes stick out past the foot bone but must stay rigid)
			if dmin > 0.075 * H and p.y > 0.09 * H:
				cloth = maxf(cloth, depth * clampf((dmin - 0.075 * H) / (0.05 * H), 0.0, 1.0))
		var hair := 0.0
		if headw > 0.5:
			hair = clampf((p.distance_to(head_c) - 0.07 * H) / (0.05 * H), 0.0, 1.0)
		cols[v] = Color(cloth, hair, 0.0, 1.0)
	return cols


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
	var q := a + ab * t
	return Vector2(p.x - q.x, p.z - q.z).length()


## Move a vertex's weights toward 100% on `bone` by factor t (0 = unchanged, 1 = rigid).
static func _blend_to(bones: PackedInt32Array, weights: PackedFloat32Array, o: int, nb: int, bone: int, t: float) -> void:
	if t <= 0.0:
		return
	var slot := -1
	for k in nb:
		if bones[o + k] == bone:
			slot = k
	if slot < 0:  # take the weakest slot
		slot = 0
		for k in nb:
			if weights[o + k] < weights[o + slot]:
				slot = k
		bones[o + slot] = bone
		weights[o + slot] = 0.0
	for k in nb:
		weights[o + k] = lerpf(weights[o + k], 1.0 if k == slot else 0.0, t)
	var sum := 0.0
	for k in nb:
		sum += weights[o + k]
	for k in nb:
		weights[o + k] /= maxf(sum, 1e-6)


static func _own(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_own(c, owner)
	if n != owner:
		n.owner = owner
