class_name Stage3D
extends SubViewportContainer
## The 3D world behind a fight: environment, lights, camera and arena geometry.
##
## The fight logic runs in 2D pixel coordinates. The camera looks straight down
## -Z with no tilt, so the plane z = 0 (where fighters stand) maps *linearly* onto
## the screen: 1 metre = PPM pixels. 2D effects drawn over it stay aligned, while
## scenery at z < 0 gets real perspective and parallax.

const PPM := 154.0          # pixels per metre on the fighters' plane
const FOV := 40.0

var viewport: SubViewport
var camera: Camera3D
var world_root: Node3D
var arena_id := ""
var _vp_size := Vector2(1920, 1080)
var _ground_px := 890.0


func setup(id: String, vp_size: Vector2, ground_px: float) -> void:
	arena_id = id
	_vp_size = vp_size
	_ground_px = ground_px
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(vp_size)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 200.0
	world_root.add_child(camera)
	_place_camera()
	ArenaBuilder.build(id, world_root)


func _place_camera() -> void:
	var d := (_vp_size.y / 2.0) / (PPM * tan(deg_to_rad(FOV / 2.0)))
	var cam_y := (_ground_px - _vp_size.y / 2.0) / PPM
	camera.position = Vector3(0.0, cam_y, d)
	camera.rotation = Vector3.ZERO
	camera.current = true


## Logic pixel position -> 3D point on the fighters' plane.
func to_world(px: Vector2) -> Vector3:
	return Vector3((px.x - _vp_size.x / 2.0) / PPM, (_ground_px - px.y) / PPM, 0.0)


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
