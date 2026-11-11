extends Node
## Keeps story progress: victory flags (fight01_completed .. fight08_completed),
## which scenes have been seen, and where "Continue" should resume.
## Saved to user://save.json.

const SAVE_PATH := "user://save.json"

## Chapter list used by Chapter Select. A chapter is unlocked when `requires`
## is empty or that flag is set. `start` is where the chapter begins.
const CHAPTERS := [
	{"title": "Prologue — The Falling Star", "requires": "", "start": {"type": "story", "id": "prologue"}},
	{"title": "Chapter 1 — Kael vs. Rhex", "requires": "prologue_seen", "start": {"type": "story", "id": "ch01_pre"}},
]

var flags: Dictionary = {}
var resume_point: Dictionary = {}


func _ready() -> void:
	load_game()


func set_flag(flag_name: String, value: bool = true) -> void:
	if flag_name.is_empty():
		return
	flags[flag_name] = value
	save_game()


func has_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))


func set_resume(point: Dictionary) -> void:
	# Only story scenes and fights are meaningful resume points.
	if point.get("type", "") in ["story", "fight"]:
		resume_point = point.duplicate()
		save_game()


func has_save() -> bool:
	return not resume_point.is_empty()


func is_chapter_unlocked(index: int) -> bool:
	var req: String = CHAPTERS[index]["requires"]
	return req.is_empty() or has_flag(req)


func new_game() -> void:
	flags = {}
	resume_point = {}
	save_game()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({"version": 1, "flags": flags, "resume": resume_point}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		flags = data.get("flags", {})
		resume_point = data.get("resume", {})
