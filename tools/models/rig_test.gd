extends Node3D
## Before/after check of tools/models/fix_rig.gd: bends the neck and wrists hard and renders
## the original Mixamo FBX (left) next to the fixed scene (right), and reports how far head
## vertices drift from a rigid head (0 cm = moves as one solid piece).
##   godot --path . --rendering-method gl_compatibility res://tools/models/rig_test.tscn -- kael out.png

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0]
	var out: String = args[1]
	var before: Node3D = load("res://assets/characters/%s/%s.fbx" % [name, name]).instantiate()
	var after: Node3D = load("res://assets/characters/%s/%s.tscn" % [name, name]).instantiate()
	var fixed_root: Node3D = after.get_child(0)
	before.scale = fixed_root.scale
	before.position = fixed_root.position + Vector3(-0.55, 0, 0)
	after.position = Vector3(0.55, 0, 0)
	for ap in before.find_children("*", "AnimationPlayer", true, false):
		ap.queue_free()
	add_child(before)
	add_child(after)
	for m in [before, after]:
		_pose(m.find_children("*", "Skeleton3D", true, false)[0])
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2a2f3a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.87, 0.92)
	env.environment.ambient_light_energy = 0.9
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 20, 0)
	add_child(key)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 2.3)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.fov = 40
	add_child(cam)
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for m in [before, after]:
		print("RIGTEST %s %s head drift: %.2f cm" % [name, "before" if m == before else "after ", _drift(m) * 100.0])
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	get_tree().quit()


func _pose(sk: Skeleton3D) -> void:
	var rot := {
		"mixamorig_Neck": Vector3(35, 0, 15), "mixamorig_Head": Vector3(10, 40, 0),
		"mixamorig_LeftHand": Vector3(0, 0, 70), "mixamorig_RightHand": Vector3(60, 0, 0),
		"mixamorig_Spine2": Vector3(10, 0, 0),
	}
	for b in rot:
		var i := sk.find_bone(b)
		var r: Vector3 = rot[b]
		sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() *
			Quaternion.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))))


## Mean distance (metres, after scaling) between each face vertex's skinned position and where
## a perfectly rigid head would put it.
func _drift(model: Node3D) -> float:
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := mi.skin
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var nb := bones.size() / verts.size()
	var xf := []
	var head_bind := -1
	for b in skin.get_bind_count():
		var bn := skin.get_bind_name(b)
		var bi := sk.find_bone(bn) if bn != "" else skin.get_bind_bone(b)
		xf.append(sk.get_bone_global_pose(bi) * skin.get_bind_pose(b))
		if sk.get_bone_name(bi) == "mixamorig_Head":
			head_bind = b
	var head_rest: Vector3 = skin.get_bind_pose(head_bind).affine_inverse().origin
	var neck_rest: Vector3 = skin.get_bind_pose(_bind(skin, sk, "mixamorig_Neck")).affine_inverse().origin
	# face region: clearly above the jaw line (same rule as fix_rig, without the blend band)
	var cut := head_rest.y - 0.25 * (head_rest.y - neck_rest.y)
	var total := 0.0
	var n := 0
	for v in verts.size():
		var p := verts[v]
		if p.y < cut or Vector2(p.x - head_rest.x, p.z - head_rest.z).length() > 0.06 * mi.mesh.get_aabb().size.y:
			continue
		var skinned := Vector3.ZERO
		for k in nb:
			skinned += (xf[bones[v * nb + k]] * p) * w[v * nb + k]
		var rigid: Vector3 = xf[head_bind] * p
		total += skinned.distance_to(rigid)
		n += 1
	return total / maxf(n, 1) * model.get_child(0).scale.x if model.get_child_count() > 0 and model.get_child(0) is Node3D and model.get_child(0).scale.x > 1.5 else total / maxf(n, 1) * model.scale.x


func _bind(skin: Skin, sk: Skeleton3D, bone: String) -> int:
	for b in skin.get_bind_count():
		var bn := skin.get_bind_name(b)
		if bn == bone or (bn == "" and sk.get_bone_name(skin.get_bind_bone(b)) == bone):
			return b
	return -1
