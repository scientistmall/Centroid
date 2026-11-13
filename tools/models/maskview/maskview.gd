extends Node3D
## Debug: render a fixed character with its flex mask as colour (red = cloth, green = hair).
##   godot --path . --rendering-method gl_compatibility res://tools/models/maskview/maskview.tscn -- kael out.png
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var m: Node3D = load("res://assets/characters/%s/%s.tscn" % [args[0], args[0]]).instantiate()
	add_child(m)
	var sh := Shader.new()
	sh.code = "shader_type spatial; render_mode unshaded; void fragment(){ ALBEDO = vec3(0.25) + vec3(COLOR.r, COLOR.g, 0.0) * 0.75; }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	var m2: Node3D = m.duplicate()
	add_child(m2)
	m2.rotation_degrees.y = 90
	m.position.x = -0.6
	m2.position.x = 0.6
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.95, 3.6)
	cam.fov = 35
	add_child(cam)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[1])
	get_tree().quit()
