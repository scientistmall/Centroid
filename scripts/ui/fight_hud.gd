class_name FightHud
extends Control
## Health / energy bars, names, round pips, timer, and a centre banner.

var left: Fighter
var right: Fighter
var wins := [0, 0]
var rounds_to_win := 2
var time_left := 99.0
var _trail := [1.0, 1.0]
var _banner: Label
var _sub: Label
var _power_label: Label
var _power_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = _mk_label(150, Color(1, 0.95, 0.85))
	_banner.set_anchor(SIDE_TOP, 0.3, true)
	_banner.set_anchor(SIDE_BOTTOM, 0.5, true)
	_sub = _mk_label(48, Color(0.8, 0.85, 1.0))
	_sub.set_anchor(SIDE_TOP, 0.5, true)
	_sub.set_anchor(SIDE_BOTTOM, 0.58, true)
	_power_label = _mk_label(44, Color.WHITE)
	_power_label.set_anchor(SIDE_TOP, 0.2, true)
	_power_label.set_anchor(SIDE_BOTTOM, 0.26, true)


func _mk_label(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.set_anchor(SIDE_LEFT, 0.0, true)
	l.set_anchor(SIDE_RIGHT, 1.0, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func banner(text: String, sub: String = "") -> void:
	_banner.text = text
	_sub.text = sub
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ONE


func clear_banner() -> void:
	_banner.text = ""
	_sub.text = ""


func show_power(f: Fighter, power_name: String) -> void:
	_power_label.text = power_name.to_upper()
	_power_label.add_theme_color_override("font_color", f.color.lightened(0.3))
	_power_t = 1.1


func _process(delta: float) -> void:
	for i in 2:
		var f := left if i == 0 else right
		if f:
			var r := f.hp / f.max_hp
			_trail[i] = r if r > _trail[i] else move_toward(_trail[i], r, delta * 0.5)
	_power_t -= delta
	_power_label.modulate.a = clampf(_power_t * 2.0, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var bar_w := w * 0.36
	var top := 40.0
	var font := get_theme_default_font()
	for i in 2:
		var f := left if i == 0 else right
		if f == null:
			continue
		var x0 := 50.0 if i == 0 else w - 50.0 - bar_w
		var r := f.hp / f.max_hp
		var e := f.energy / Fighter.MAX_ENERGY
		# HP frame
		draw_rect(Rect2(x0 - 4, top - 4, bar_w + 8, 44), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(x0, top, bar_w, 36), Color(0.15, 0.05, 0.07))
		var trail_w: float = bar_w * _trail[i]
		var hp_w := bar_w * r
		var hp_col := Color(0.95, 0.85, 0.3) if r > 0.3 else Color(1.0, 0.3, 0.25)
		if i == 0:
			draw_rect(Rect2(x0, top, trail_w, 36), Color(1, 1, 1, 0.8))
			draw_rect(Rect2(x0, top, hp_w, 36), hp_col)
		else:
			draw_rect(Rect2(x0 + bar_w - trail_w, top, trail_w, 36), Color(1, 1, 1, 0.8))
			draw_rect(Rect2(x0 + bar_w - hp_w, top, hp_w, 36), hp_col)
		# Energy
		var ey := top + 50.0
		var ew := bar_w * 0.7
		var ex := x0 if i == 0 else x0 + bar_w - ew
		draw_rect(Rect2(ex - 3, ey - 3, ew + 6, 22), Color(0, 0, 0, 0.75))
		var ecol := f.color if e < 0.999 else f.color.lightened(0.4 + 0.3 * sin(Time.get_ticks_msec() / 90.0))
		if i == 0:
			draw_rect(Rect2(ex, ey, ew * e, 16), ecol)
		else:
			draw_rect(Rect2(ex + ew * (1.0 - e), ey, ew * e, 16), ecol)
		for k in range(1, 4):
			draw_line(Vector2(ex + ew * k / 4.0, ey), Vector2(ex + ew * k / 4.0, ey + 16), Color(0, 0, 0, 0.8), 2)
		# Name
		var nx := x0 if i == 0 else x0 + bar_w - font.get_string_size(f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string_outline(font, Vector2(nx, ey + 66), f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8, Color.BLACK)
		draw_string(font, Vector2(nx, ey + 66), f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, f.color.lightened(0.25))
		# Round pips
		for k in rounds_to_win:
			var px := (x0 + bar_w - 20 - k * 34) if i == 0 else (x0 + 20 + k * 34)
			draw_circle(Vector2(px, ey + 50), 12, Color(0, 0, 0, 0.8))
			draw_circle(Vector2(px, ey + 50), 8, Color(1, 0.85, 0.3) if wins[i] > k else Color(0.25, 0.25, 0.3))
	# Timer
	var ts := str(int(ceil(maxf(0.0, time_left))))
	var tw := font.get_string_size(ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	draw_string_outline(font, Vector2(w / 2 - tw / 2, top + 54), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, 10, Color.BLACK)
	draw_string(font, Vector2(w / 2 - tw / 2, top + 54), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE)
