extends Node3D
## Renders a 4-view sheet (front, 3/4, side, back) of a GLB model.
## godot --path tools/models/preview -- <model.glb> <out.png> [title]

const VIEWS := [0.0, 45.0, 90.0, 180.0]
const NAMES := ["FRONT", "3/4", "SIDE", "BACK"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var out: String = args[1]
	var title: String = args[2] if args.size() > 2 else src.get_file()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(src, state) != OK:
		push_error("cannot load " + src)
		get_tree().quit(1)
		return
	var model: Node3D = doc.generate_scene(state)
	_fix_materials(model)
	# fit: feet on the ground, ~1.8 units tall, centred
	var aabb := _aabb(model, Transform3D.IDENTITY)
	var s := 1.8 / maxf(aabb.size.y, 0.001)
	model.scale = Vector3.ONE * s
	model.position = -Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z) * s
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.add_child(model)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2a2f3a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_energy = 1.1
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 200, 0)
	fill.light_energy = 0.5
	add_child(fill)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.95, 4.2)
	cam.fov = 30
	add_child(cam)
	cam.make_current()
	var vp := get_viewport()
	var sheet := Image.create(1600, 1000, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("2a2f3a"))
	for i in VIEWS.size():
		pivot.rotation_degrees.y = VIEWS[i]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var w := 400
		var crop := img.get_region(Rect2i(600, 0, 400, 1000))
		sheet.blit_rect(crop, Rect2i(0, 0, w, 1000), Vector2i(i * w, 0))
	sheet.save_png(out)
	print("preview: ", out, " title=", title, " tris_scale=", s)
	get_tree().quit()


## Untextured meshes (shape-only output) get a lit clay material and smooth normals.
func _fix_materials(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null or mat.albedo_texture == null:
				var st := SurfaceTool.new()
				st.create_from(mi.mesh, s)
				st.generate_normals()
				var clay := StandardMaterial3D.new()
				clay.albedo_color = Color(0.78, 0.76, 0.72)
				clay.roughness = 0.8
				var m := st.commit()
				m.surface_set_material(0, clay)
				mi.mesh = m
				break
	for c in n.get_children():
		_fix_materials(c)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		box = t * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size != Vector3.ZERO:
			box = b if first else box.merge(b)
			first = false
	return box
