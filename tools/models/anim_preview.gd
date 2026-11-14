extends Node3D
## Preview Mixamo clips on a game character: each clip is retargeted onto the model (as the game
## does) and six moments of it are rendered in a row, one row per clip, into one contact sheet.
##
##   DISPLAY=:99 godot --path . --rendering-method gl_compatibility --resolution 1800x300 \
##     res://tools/models/anim_preview.tscn -- <model.glb> <out.png> <clip.fbx> [clip.fbx ...]
## Clips load at runtime (FBXDocument), so they don't need importing into the project.

const FRAMES := 6
const CELL := Vector2i(300, 300)

var _vp: SubViewport
var _cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var model_path: String = args[0]
	var out: String = args[1]
	var clips := args.slice(2)
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.86, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.7
	env.environment = e
	_vp.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 30, 0)
	_vp.add_child(l)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_vp.add_child(_cam)
	var sheet := Image.create(CELL.x * FRAMES, CELL.y * clips.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for ci in clips.size():
		var model: Node3D = (load(model_path) as PackedScene).instantiate()
		_vp.add_child(model)
		model.rotation.y = 0.7   # three-quarter view, as in a fight
		var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var src := _load_fbx(clips[ci])
		if src.is_empty():
			model.queue_free()
			continue
		var lib := AnimationLibrary.new()
		lib.add_animation("c", src["anim"])
		var rl := VrmRetarget.library(clips[ci], lib, src["skeleton"], sk)
		var ap := AnimationPlayer.new()
		sk.get_parent().add_child(ap)
		ap.add_animation_library("", rl)
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		ap.play("c")
		var length: float = rl.get_animation("c").length
		for fi in FRAMES:
			ap.seek(length * fi / (FRAMES - 1.0) * 0.999, true)
			var hips := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips")).origin
			_cam.global_position = Vector3(hips.x, 1.0, hips.z + 3.9)
			_cam.look_at(Vector3(hips.x, 0.95, hips.z))
			await RenderingServer.frame_post_draw
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(fi * CELL.x, ci * CELL.y))
		model.queue_free()
		(src["root"] as Node).queue_free()
		await get_tree().process_frame
		print("previewed ", clips[ci].get_file(), " ", snappedf(length, 0.01), "s")
	sheet.save_png(out)
	get_tree().quit()


func _load_fbx(path: String) -> Dictionary:
	if path.ends_with(".json"):   # an AI clip (HY-Motion), with its skeleton.json beside it
		var sk := AiClips.skeleton(path.get_base_dir())
		var holder := Node3D.new()
		holder.add_child(sk)
		add_child(holder)
		return {"root": holder, "anim": AiClips.animation(path, sk), "skeleton": sk}
	var doc := FBXDocument.new()
	var state := FBXState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("cannot read " + path)
		return {}
	var root: Node = doc.generate_scene(state)
	add_child(root)
	var aps := root.find_children("*", "AnimationPlayer", true, false)
	var sks := root.find_children("*", "Skeleton3D", true, false)
	if aps.is_empty() or sks.is_empty():
		return {}
	var ap: AnimationPlayer = aps[0]
	var anim: Animation = ap.get_animation(ap.get_animation_list()[0])
	return {"root": root, "anim": anim, "skeleton": sks[0]}
