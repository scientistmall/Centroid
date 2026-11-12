class_name FightHud
extends Control
## Fight HUD in the heavy-metal style: portrait frames, slanted beveled health bars
## with damage chip-lag, 3-segment power meters, metal timer badge, round pips,
## combo counter and slam-in banners (FIGHT! / K.O.).

var left: Fighter:
	set(v):
		left = v
		_set_portrait(0, v)
var right: Fighter:
	set(v):
		right = v
		_set_portrait(1, v)
var wins := [0, 0]
var rounds_to_win := 2
var time_left := 99.0

var _trail := [1.0, 1.0]
var _banner := ""
var _sub := ""
var _banner_t := 0.0
var _banner_col := Color.WHITE
var _combo := 0
var _combo_t := 99.0
var _combo_pop := 0.0
var _frames: Array = [null, null]
var _portraits: Array = [null, null]
var _t := 0.0

const BAR_H := 46.0
const FRAME := 150.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var fr := Control.new()
		fr.clip_contents = true
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fr)
		var p := Portrait.new()
		fr.add_child(p)
		_frames[i] = fr
		_portraits[i] = p
	resized.connect(_layout)
	_layout()
	if left:
		_set_portrait(0, left)
	if right:
		_set_portrait(1, right)


func _layout() -> void:
	for i in 2:
		var fr: Control = _frames[i]
		if fr == null:
			continue
		var x := 26.0 if i == 0 else size.x - 26.0 - FRAME
		fr.position = Vector2(x + 6, 22)
		fr.size = Vector2(FRAME - 12, FRAME - 12)
		var p: Portrait = _portraits[i]
		p.position = Vector2(-FRAME * 0.55, -FRAME * 0.12)
		p.size = Vector2(FRAME * 2.2, FRAME * 2.6)


func _set_portrait(i: int, f: Fighter) -> void:
	if f == null or _portraits[i] == null:
		return
	_portraits[i].set_character(f.char_id, i == 1)
	_portraits[i].set_expression("determined")


# ---------------------------------------------------------------- API used by the arena

func banner(text: String, sub: String = "") -> void:
	_banner = text
	_sub = sub
	_banner_t = 0.0
	_banner_col = Color("ff5a4a") if text in ["K.O.", "DEFEAT"] else (Metal.GOLD if text == "FIGHT!" else Color.WHITE)


func clear_banner() -> void:
	_banner = ""
	_sub = ""


func show_power(_f: Fighter, _power_name: String) -> void:
	pass   # the cut-in banner shows power names now


## Called when the left fighter lands a hit (combo) or takes one (combo breaks).
func register_hit(by_left: bool) -> void:
	if by_left:
		_combo = _combo + 1 if _combo_t < 2.0 else 1
		_combo_t = 0.0
		_combo_pop = 1.0
	else:
		_combo = 0


func _process(delta: float) -> void:
	_t += delta
	_banner_t += delta
	_combo_t += delta
	_combo_pop = maxf(0.0, _combo_pop - delta * 5.0)
	for i in 2:
		var f := left if i == 0 else right
		if f:
			var r := f.hp / f.max_hp
			_trail[i] = r if r > _trail[i] else move_toward(_trail[i], r, delta * 0.45)
	if _portraits[0]:
		for i in 2:
			var f2 := left if i == 0 else right
			if f2:
				_portraits[i].set_expression("angry" if f2.state == Fighter.S.HURT else ("sad" if f2.state == Fighter.S.KO else "determined"))
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var w := size.x
	var h := size.y
	for i in 2:
		var f := left if i == 0 else right
		if f:
			_draw_side(i, f, w)
	_draw_timer(w)
	_draw_combo(h)
	_draw_banner(w, h)


func _draw_side(i: int, f: Fighter, w: float) -> void:
	var dir := 1 if i == 0 else -1
	var fx := 26.0 if i == 0 else w - 26.0 - FRAME
	# portrait frame (the Portrait child draws inside; we draw the frame over it after)
	var fr := Rect2(fx, 16, FRAME, FRAME)
	draw_rect(fr.grow(-6), Color(0.02, 0.02, 0.05))
	var cuts := [true, false, true, false] if i == 0 else [false, true, false, true]
	var frame_pts := Metal.chamfer(fr, 22.0, cuts)
	frame_pts.append(frame_pts[0])
	draw_polyline(frame_pts, f.color.lightened(0.2), 5.0)
	# name plate
	var bar_x0 := fx + FRAME + 14 if i == 0 else w * 0.565
	var bar_x1 := w * 0.435 if i == 0 else fx - 14
	var bar_w := bar_x1 - bar_x0
	var name_y := 40.0
	var nf := Metal.display_bold()
	var nm := f.display_name
	var nw := nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	var nx := bar_x0 + 6 if i == 0 else bar_x1 - nw - 6
	draw_string_outline(nf, Vector2(nx, name_y + 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 8, Color(0, 0, 0, 0.9))
	draw_string(nf, Vector2(nx, name_y + 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color.WHITE)
	# health bar
	var r := f.hp / f.max_hp
	var low := r < 0.3
	var top := Color("ff6a5a") if low else Color("fff07a")
	var bot := Color("b01e18") if low else Color("e09a14")
	var hb := Rect2(bar_x0, 66, bar_w, BAR_H)
	Metal.slant_bar(self, hb, r, top, bot, _trail[i], dir, 18.0, f.color.lightened(0.35))
	# power meter: 3 segments
	var seg_w := bar_w * 0.62 / 3.0
	var e := f.energy / Fighter.MAX_ENERGY
	for k in 3:
		var sx := bar_x0 + k * (seg_w + 8) if i == 0 else bar_x1 - (k + 1) * seg_w - k * 8
		var seg_frac := clampf(e * 3.0 - k, 0.0, 1.0)
		var full := seg_frac >= 1.0
		var col := f.color.lightened(0.15)
		if full:
			col = col.lerp(Color.WHITE, 0.25 + 0.2 * sin(_t * 6.0 + k))
		Metal.slant_bar(self, Rect2(sx, 66 + BAR_H + 10, seg_w, 22), seg_frac, col.lightened(0.3), col.darkened(0.3), -1.0, dir, 10.0,
			Color(f.color, 0.8 if full else 0.4))
	# round pips (diamonds)
	for k in rounds_to_win:
		var px := bar_x1 - 18 - k * 36 if i == 0 else bar_x0 + 18 + k * 36
		var c := Vector2(px, 66 + BAR_H + 22)
		var lit: bool = wins[i] > k
		var d := PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 0), c + Vector2(0, 12), c + Vector2(-12, 0)])
		draw_colored_polygon(d, Metal.GOLD if lit else Color(0.15, 0.16, 0.2))
		d.append(d[0])
		draw_polyline(d, Color(1, 1, 1, 0.5), 2.0)


func _draw_timer(w: float) -> void:
	var r := Rect2(w / 2 - 70, 14, 140, 112)
	Metal.panel(self, r, Metal.GOLD, 20.0, Color("3b4352"), Color("10131a"), 0.5, [true, true, true, true])
	var ts := str(int(ceil(maxf(0.0, time_left))))
	var col := Color("ff5a4a") if time_left < 10.0 else Color.WHITE
	Metal.shout(self, Vector2(w / 2, 104), ts, 86, col, Metal.GOLD)


func _draw_combo(h: float) -> void:
	if _combo < 2 or _combo_t > 1.8:
		return
	var a := clampf((1.8 - _combo_t) / 0.4, 0.0, 1.0)
	var sc := 1.0 + _combo_pop * 0.35
	var base := Vector2(60, h * 0.42)
	draw_set_transform(base, -0.08, Vector2(sc, sc))
	var f := Metal.display_bold()
	var n := str(_combo)
	draw_string_outline(f, Vector2.ZERO, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, 16, Color(0, 0, 0, 0.9 * a))
	draw_string(f, Vector2.ZERO, n, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, Color(Metal.GOLD, a))
	var nw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 120).x
	draw_string_outline(f, Vector2(nw + 10, -8), "HITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 10, Color(0, 0, 0, 0.9 * a))
	draw_string(f, Vector2(nw + 10, -8), "HITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)


func _draw_banner(w: float, h: float) -> void:
	if _banner == "":
		return
	# slam in: big -> normal with a flash, slight shake
	var k := clampf(_banner_t / 0.18, 0.0, 1.0)
	var sc := lerpf(2.4, 1.0, ease(k, 0.3))
	var shake := (1.0 - clampf((_banner_t - 0.18) / 0.25, 0.0, 1.0)) * 10.0 * (1.0 if k >= 1.0 else 0.0)
	var c := Vector2(w / 2 + randf_range(-shake, shake), h * 0.46)
	# dark band behind the text
	var band_a := clampf(_banner_t / 0.12, 0.0, 1.0) * 0.55
	draw_colored_polygon(PackedVector2Array([Vector2(0, c.y - 120), Vector2(w, c.y - 150), Vector2(w, c.y + 40), Vector2(0, c.y + 70)]),
		Color(0, 0, 0, band_a))
	draw_set_transform(c, -0.03, Vector2(sc, sc))
	Metal.shout(self, Vector2(0, 0), _banner, 170, _banner_col, _banner_col)
	draw_set_transform(Vector2.ZERO)
	if k < 1.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, (1.0 - k) * 0.25))
	if _sub != "":
		Metal.shout(self, Vector2(w / 2, c.y + 64), _sub, 54, Color(0.85, 0.9, 1.0), Metal.CYAN)
