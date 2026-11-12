extends Node
## Keeps story progress: victory flags (fight01_completed .. fight08_completed),
## which scenes have been seen, and where "Continue" should resume.
## Saved to user://save.json.

const SAVE_PATH := "user://save.json"

## Chapter list used by the 37 Days chapter select. A chapter is unlocked when
## `requires` is empty or that flag is set, and completed when `done` is set.
const CHAPTERS := [
	{"title": "Prologue — The Falling Star", "short": "PROLOGUE", "day": 1, "day_label": "YEARS AGO", "place": "The Falling Star",
		"fighters": ["auren", "veyr"], "requires": "", "done": "prologue_seen", "start": {"type": "story", "id": "prologue"}},
	{"title": "Chapter 1 — Kael vs. Rhex", "short": "CHAPTER 1", "day": 4, "day_label": "DAY 4", "place": "The Abandoned Training Ground",
		"fighters": ["kael", "rhex"], "requires": "prologue_seen", "done": "fight01_completed", "start": {"type": "story", "id": "ch01_pre"}},
	{"title": "Chapter 2 — Tala vs. Vaska", "short": "CHAPTER 2", "day": 10, "day_label": "DAY 10", "place": "The Silent Forest",
		"fighters": ["tala", "vaska"], "requires": "fight01_completed", "done": "fight02_completed", "start": {"type": "story", "id": "ch02_pre"}},
	{"title": "Chapter 3 — Darin vs. Mael", "short": "CHAPTER 3", "day": 14, "day_label": "DAY 14", "place": "The Broken Pass",
		"fighters": ["darin", "mael"], "requires": "fight02_completed", "done": "fight03_completed", "start": {"type": "story", "id": "ch03_pre"}},
	{"title": "Chapter 4 — Mira vs. Nyra", "short": "CHAPTER 4", "day": 20, "day_label": "DAY 20", "place": "The Underground Sanctuary",
		"fighters": ["mira", "nyra"], "requires": "fight03_completed", "done": "fight04_completed", "start": {"type": "story", "id": "ch04_pre"}},
]
const TOTAL_DAYS := 37


func is_chapter_done(index: int) -> bool:
	return has_flag(CHAPTERS[index]["done"])


## Furthest day reached (for the "Day X of 37" progress bar).
func days_reached() -> int:
	var d := 0
	for i in CHAPTERS.size():
		if is_chapter_done(i):
			d = maxi(d, int(CHAPTERS[i]["day"]))
	return d


func chapters_done() -> int:
	var c := 0
	for i in range(1, CHAPTERS.size()):
		if is_chapter_done(i):
			c += 1
	return c

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
