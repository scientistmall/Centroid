class_name ChapterCard
extends Control
## One chapter on the 37 Days timeline: day, place, both fighters facing off,
## and a status ribbon (LOCKED / NEW / COMPLETED). Tap to start the chapter.

signal chosen(index: int)

var index := 0
var info: Dictionary = {}
var unlocked := false
var done := false
var _left: Portrait
var _right: Portrait
var _t := 0.0
var _pressed := false


func _ready() -> void:
	custom_minimum_size = Vector2(500, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var f: Array = info.get("fighters", [])
	_left = _portrait(f[0] if f.size() > 0 else "", false)
	_right = _portrait(f[1] if f.size() > 1 else "", true)
	var dim := Color(0.25, 0.25, 0.3) if not unlocked else Color.WHITE
	_left.modulate = dim
	_right.modulate = dim


func _portrait(id: String, right: bool) -> Portrait:
	var p := Portrait.new()
	p.set_anchor(SIDE_TOP, 0.30, true)
	p.set_anchor(SIDE_BOTTOM, 0.80, true)
	p.set_anchor(SIDE_LEFT, 0.50 if right else 0.0, true)
	p.set_anchor(SIDE_RIGHT, 1.0 if right else 0.5, true)
	p.clip_contents = true
	add_child(p)
	p.set_character(id, right)
	p.set_expression("determined")
	return p


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and unlocked:
		if event.pressed:
			_pressed = true
		elif _pressed:
			_pressed = false
			AudioManager.sfx("ui_confirm")
			chosen.emit(index)
		accept_event()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var accent := UiStyle.GOLD if done else (UiStyle.ACCENT if unlocked else Color(0.4, 0.4, 0.45))
	var lift := -6.0 if _pressed else 0.0
	draw_set_transform(Vector2(0, lift))
	draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.035, 0.07, 0.92))
	draw_rect(Rect2(0, 0, w, h), Color(accent, 0.6), false, 3.0)
	draw_rect(Rect2(0, 0, w, 8), accent)
	var tf := UiStyle.title_font()
	var uf := UiStyle.bold_font()
	var day: String = info.get("day_label", "")
	draw_string(tf, Vector2(28, 92), day, HORIZONTAL_ALIGNMENT_LEFT, -1, 58, accent.lightened(0.2))
	draw_string(uf, Vector2(30, 140), String(info.get("short", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiStyle.MUTED)
	draw_string(uf, Vector2(30, 178), String(info.get("place", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 60, 32, UiStyle.TEXT)
	# VS mark between the portraits
	draw_string(tf, Vector2(w / 2 - 34, h * 0.56), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1, 1, 1, 0.5 if unlocked else 0.15))
	# status ribbon
	var ry := h - 96.0
	draw_rect(Rect2(0, ry, w, 96), Color(0, 0, 0, 0.55))
	var status := "COMPLETED" if done else ("NEW" if unlocked else "LOCKED")
	var col := UiStyle.GOLD if done else (UiStyle.ACCENT if unlocked else Color(0.5, 0.5, 0.55))
	if status == "NEW":
		col = col.lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 4.0))
	var icon_c := Vector2(48, ry + 48)
	if done:
		draw_polyline(PackedVector2Array([icon_c + Vector2(-14, 0), icon_c + Vector2(-4, 12), icon_c + Vector2(16, -14)]), col, 6.0)
	elif unlocked:
		draw_colored_polygon(PackedVector2Array([icon_c + Vector2(-10, -16), icon_c + Vector2(16, 0), icon_c + Vector2(-10, 16)]), col)
	else:
		draw_rect(Rect2(icon_c + Vector2(-14, -4), Vector2(28, 22)), col)
		draw_arc(icon_c + Vector2(0, -6), 10, PI, TAU, 12, col, 5.0)
	draw_string(uf, Vector2(84, ry + 62), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, col)
	draw_set_transform(Vector2.ZERO)
