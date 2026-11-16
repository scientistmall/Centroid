class_name Stage3D
extends SubViewportContainer
## The 3D world behind a fight: environment, lights, camera and arena geometry.
##
## The fight logic runs in 2D pixel coordinates. The camera looks straight down
## -Z with no tilt, so the plane z = 0 (where fighters stand) maps *linearly* onto
## the screen: 1 metre = PPM pixels. 2D effects drawn over it stay aligned, while
## scenery at z < 0 gets real perspective and parallax.

const PPM := 154.0          # pixels per metre on the fighters' plane
## The stage of the fight in progress (for 3D power effects), or null.
static var current: Stage3D
const FOV := 40.0

var viewport: SubViewport          # null in SAFE graphics: the 3D then draws straight to the screen
var camera: Camera3D
var level := Settings.Gfx.HIGH
## Dynamic resolution (phones): the 3D render scale steps down when frames run long and back up
## when there is headroom, so the fight holds its frame rate; the HUD stays at full resolution.
const SCALE_MIN := 0.6
var render_scale := 1.0
var scale_max := 1.0
var dynamic := false
var _avg_ms := 16.7
var _last_us := 0
var _dyn := {"slow": 0.0, "fast": 0.0, "cool": 0.0}
var world_root: Node3D
var arena_id := ""
var _vp_size := Vector2(1920, 1080)
var _ground_px := 890.0


func setup(id: String, vp_size: Vector2, ground_px: float) -> void:
	current = self
	tree_exiting.connect(func(): if current == self: current = null)
	arena_id = id
	_vp_size = vp_size
	_ground_px = ground_px
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	level = Settings.effective_graphics()
	ArenaBuilder.low = level != Settings.Gfx.HIGH
	ArenaBuilder.blob_shadows = ArenaBuilder.low or OS.has_feature("mobile") or OS.get_environment("BLOB_SHADOWS") == "1"
	world_root = Node3D.new()
	if level == Settings.Gfx.SAFE:
		# no off-screen render: the world joins the screen's own viewport and draws under every
		# canvas layer (this stage sits on the lowest one, so the picture is the same)
		var root_vp := get_viewport()
		render_scale = 0.75
		scale_max = 0.85
		root_vp.scaling_3d_scale = render_scale
		tree_exiting.connect(func(): root_vp.scaling_3d_scale = 1.0)
		add_child(world_root)
	else:
		viewport = SubViewport.new()
		viewport.size = Vector2i(vp_size)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_2X if level == Settings.Gfx.HIGH else Viewport.MSAA_DISABLED
		if level == Settings.Gfx.LOW:
			render_scale = 0.75
			scale_max = 0.85
		elif OS.has_feature("mobile"):
			render_scale = 0.85   # phones: dense screens, the difference doesn't show
		viewport.scaling_3d_scale = render_scale
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		viewport.add_child(world_root)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 200.0
	world_root.add_child(camera)
	_place_camera()
	ArenaBuilder.build(id, world_root, camera.position.y, camera.position.z)
	dynamic = OS.has_feature("mobile") or OS.get_environment("DYNRES") == "1"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not dynamic:
		return
	var now := Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
		return
	var dt := (now - _last_us) / 1e6
	_last_us = now
	if dt > 0.25:
		return   # a hitch (loading, pause): not a trend
	_avg_ms = lerpf(_avg_ms, dt * 1000.0, 0.1)
	var s := step_scale(render_scale, _avg_ms, dt, _dyn, scale_max)
	if not is_equal_approx(s, render_scale):
		render_scale = s
		(viewport if viewport else get_viewport()).scaling_3d_scale = s


## One step of the dynamic-resolution rule (pure; tests feed it frame times). Budget: 60 fps.
## Over budget by 15% for half a second: one step down. Comfortably inside it for three seconds
## (and not within eight seconds of a step down): one step back up.
static func step_scale(scale: float, avg_ms: float, dt: float, st: Dictionary, max_scale := 1.0) -> float:
	var budget := 1000.0 / 60.0
	st["cool"] = maxf(0.0, float(st["cool"]) - dt)
	if avg_ms > budget * 1.15:
		st["fast"] = 0.0
		st["slow"] = float(st["slow"]) + dt
		if st["slow"] >= 0.5:
			st["slow"] = 0.0
			st["cool"] = 8.0
			return maxf(SCALE_MIN, scale - 0.08)
	elif avg_ms < budget * 1.04:
		st["slow"] = 0.0
		st["fast"] = float(st["fast"]) + dt
		if st["fast"] >= 3.0 and st["cool"] <= 0.0 and scale < max_scale:
			st["fast"] = 0.0
			return minf(max_scale, scale + 0.05)
	else:
		st["slow"] = 0.0
		st["fast"] = 0.0
	return scale


func _place_camera() -> void:
	var d := (_vp_size.y / 2.0) / (PPM * tan(deg_to_rad(FOV / 2.0)))
	var cam_y := (_ground_px - _vp_size.y / 2.0) / PPM
	camera.position = Vector3(0.0, cam_y, d)
	camera.rotation = Vector3.ZERO
	camera.current = true


## Logic pixel position -> 3D point on the fighters' plane.
func to_world(px: Vector2) -> Vector3:
	return Vector3((px.x - _vp_size.x / 2.0) / PPM, (_ground_px - px.y) / PPM, 0.0)


## Inverse of to_world (depth is ignored): a 3D point -> logic / 2D world pixels.
func to_logic(w: Vector3) -> Vector2:
	return Vector2(w.x * PPM + _vp_size.x / 2.0, _ground_px - w.y * PPM)


## Follow-and-zoom camera (MCOC-style framing). `focus_x` is the logic x the
## screen centre looks at, `zoom` scales the fighters' plane, `shake` is in px.
## Returns the Transform2D the 2D world layer must use so 2D effects stay aligned.
func frame(focus_x: float, zoom: float, shake: Vector2) -> Transform2D:
	var ppm := PPM * zoom
	var d := (_vp_size.y / 2.0) / (ppm * tan(deg_to_rad(FOV / 2.0)))
	var cam_y := (_ground_px - _vp_size.y / 2.0) / ppm
	camera.position = Vector3((focus_x - _vp_size.x / 2.0) / PPM, cam_y, d)
	camera.h_offset = -shake.x / ppm
	camera.v_offset = shake.y / ppm
	# 2D: screen = (logic - (focus, ground)) * zoom + (centre, ground) + shake
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0,
		Vector2(_vp_size.x / 2.0 - zoom * focus_x, _ground_px - zoom * _ground_px) + shake)
