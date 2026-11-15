extends Node
## Player settings, saved to user://settings.json.

const PATH := "user://settings.json"

var music_volume := 0.8        # 0..1
var sfx_volume := 0.9          # 0..1
var vibration := true
var button_scale := 1.0        # 0.8..1.3
var button_opacity := 0.85     # 0.4..1.0
var left_handed := false       # swap joystick and buttons
var difficulty := 1            # 0 easy, 1 normal, 2 hard
## 3D quality: AUTO picks for the phone; LOW drops MSAA, glow, fog and shadows; SAFE also
## draws the 3D straight to the screen (no off-screen pass) for GPUs whose drivers fail at it.
enum Gfx { AUTO, HIGH, LOW, SAFE }
var graphics := Gfx.AUTO
var graphics_detected := 0     # 0 = not yet; else the level the black-screen check settled on

## GPU families whose drivers are known to fail at parts of the 3D pipeline: start them on LOW.
const WEAK_GPUS := ["PowerVR", "GE8", "Mali-4", "Mali-T7", "Adreno (TM) 3"]

signal changed


func _ready() -> void:
	load_settings()


## The 3D level to use now (HIGH, LOW or SAFE).
func effective_graphics() -> int:
	if graphics != Gfx.AUTO:
		return graphics
	if graphics_detected > 0:
		return graphics_detected
	var gpu := RenderingServer.get_video_adapter_name()
	for g in WEAK_GPUS:
		if gpu.contains(g):
			return Gfx.LOW
	return Gfx.HIGH


## "Compatibility · PowerVR Rogue GE8320 · OpenGL ES 3.2 · using LOW"
func graphics_info() -> String:
	var method := RenderingServer.get_current_rendering_method()
	var names := {"gl_compatibility": "Compatibility", "mobile": "Mobile", "forward_plus": "Forward+"}
	var lvl: String = ["AUTO", "HIGH", "LOW", "SAFE"][effective_graphics()]
	return "%s  ·  %s  ·  %s  ·  using %s" % [names.get(method, method), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(), lvl]


func ai_multiplier() -> float:
	return [0.7, 1.0, 1.3][clampi(difficulty, 0, 2)]


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"music_volume": music_volume, "sfx_volume": sfx_volume, "vibration": vibration,
			"button_scale": button_scale, "button_opacity": button_opacity,
			"left_handed": left_handed, "difficulty": difficulty, "graphics": graphics,
			"graphics_detected": graphics_detected}))
	changed.emit()


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		music_volume = float(d.get("music_volume", music_volume))
		sfx_volume = float(d.get("sfx_volume", sfx_volume))
		vibration = bool(d.get("vibration", vibration))
		button_scale = float(d.get("button_scale", button_scale))
		button_opacity = float(d.get("button_opacity", button_opacity))
		left_handed = bool(d.get("left_handed", left_handed))
		difficulty = int(d.get("difficulty", difficulty))
		graphics = clampi(int(d.get("graphics", graphics)), 0, 3)
		graphics_detected = clampi(int(d.get("graphics_detected", graphics_detected)), 0, 3)


func vibrate(ms: int) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
