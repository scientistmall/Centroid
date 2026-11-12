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

signal changed


func _ready() -> void:
	load_settings()


func ai_multiplier() -> float:
	return [0.7, 1.0, 1.3][clampi(difficulty, 0, 2)]


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"music_volume": music_volume, "sfx_volume": sfx_volume, "vibration": vibration,
			"button_scale": button_scale, "button_opacity": button_opacity,
			"left_handed": left_handed, "difficulty": difficulty}))
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


func vibrate(ms: int) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
