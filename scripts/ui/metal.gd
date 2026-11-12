class_name Metal
extends RefCounted
## Drawing helpers for the heavy-metal UI style: chamfered panels with brushed
## gradients, bevel highlights and glowing trims; slanted beveled bars.

const GUNMETAL_TOP := Color("3b4352")
const GUNMETAL_BOT := Color("10131a")
const GOLD_TOP := Color("ffe08a")
const GOLD_BOT := Color("b07a22")
const CYAN := Color("6fe3ff")
const GOLD := Color("f5c84c")

static var _display: Font
static var _display_bold: Font


static func display_font() -> Font:
	if _display == null:
		_display = load("res://assets/fonts/Teko-SemiBold.woff2")
	return _display


static func display_bold() -> Font:
	if _display_bold == null:
		_display_bold = load("res://assets/fonts/Teko-Bold.woff2")
	return _display_bold


## Polygon of a rectangle with cut corners. `cuts` = [top-left, top-right, bottom-right, bottom-left].
static func chamfer(r: Rect2, c: float, cuts := [true, false, true, false]) -> PackedVector2Array:
	var p := PackedVector2Array()
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	if cuts[0]:
		p.append(Vector2(x0, y0 + c)); p.append(Vector2(x0 + c, y0))
	else:
		p.append(Vector2(x0, y0))
	if cuts[1]:
		p.append(Vector2(x1 - c, y0)); p.append(Vector2(x1, y0 + c))
	else:
		p.append(Vector2(x1, y0))
	if cuts[2]:
		p.append(Vector2(x1, y1 - c)); p.append(Vector2(x1 - c, y1))
	else:
		p.append(Vector2(x1, y1))
	if cuts[3]:
		p.append(Vector2(x0 + c, y1)); p.append(Vector2(x0, y1 - c))
	else:
		p.append(Vector2(x0, y1))
	return p


static func _vertical_colors(pts: PackedVector2Array, r: Rect2, top: Color, bot: Color) -> PackedColorArray:
	var cols := PackedColorArray()
	for v in pts:
		cols.append(top.lerp(bot, clampf((v.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	return cols


## Full metal panel. `trim` is the glowing edge colour.
static func panel(ci: CanvasItem, r: Rect2, trim: Color, cut := 18.0, top := GUNMETAL_TOP, bot := GUNMETAL_BOT,
		glow := 0.6, cuts := [true, false, true, false]) -> void:
	var pts := chamfer(r, cut, cuts)
	# outer glow
	if glow > 0.0:
		for i in 3:
			var g := chamfer(r.grow(3.0 + i * 3.0), cut + i * 2.0, cuts)
			g.append(g[0])
			ci.draw_polyline(g, Color(trim, glow * (0.22 - i * 0.06)), 3.0)
	ci.draw_polygon(pts, _vertical_colors(pts, r, top, bot))
	# brushed-metal streaks
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.size.x * 7 + r.size.y)
	for i in int(r.size.y / 6.0):
		var y := r.position.y + 3 + i * 6.0
		var x0 := r.position.x + rng.randf_range(cut, r.size.x * 0.3)
		ci.draw_line(Vector2(x0, y), Vector2(x0 + rng.randf_range(r.size.x * 0.2, r.size.x * 0.6), y), Color(1, 1, 1, 0.025), 1.0)
	# bevel: top highlight, bottom shadow
	var inner := chamfer(r.grow(-4.0), maxf(2.0, cut - 3.0), cuts)
	inner.append(inner[0])
	ci.draw_polyline(inner, Color(1, 1, 1, 0.10), 2.0)
	ci.draw_line(Vector2(r.position.x + cut, r.position.y + 2), Vector2(r.end.x - 4, r.position.y + 2), Color(1, 1, 1, 0.28), 2.0)
	ci.draw_line(Vector2(r.position.x + 4, r.end.y - 2), Vector2(r.end.x - cut, r.end.y - 2), Color(0, 0, 0, 0.5), 3.0)
	# trim
	var outline := pts.duplicate()
	outline.append(outline[0])
	ci.draw_polyline(outline, trim, 3.0)


## Gold primary-action panel.
static func gold_panel(ci: CanvasItem, r: Rect2, cut := 18.0) -> void:
	panel(ci, r, Color("fff0b0"), cut, GOLD_TOP, GOLD_BOT, 0.5)


## Slanted (parallelogram) bar container + fill, e.g. health bars. `dir` = +1 fills left→right.
static func slant_bar(ci: CanvasItem, r: Rect2, frac: float, fill_top: Color, fill_bot: Color, chip := -1.0,
		dir := 1, slant := 16.0, trim := Color(1, 1, 1, 0.6)) -> void:
	var s := slant * dir
	var frame := PackedVector2Array([r.position + Vector2(maxf(0, s), 0), Vector2(r.end.x + minf(0, s), r.position.y),
		r.end + Vector2(-maxf(0, s), 0), Vector2(r.position.x - minf(0, s), r.end.y)])
	ci.draw_colored_polygon(frame, Color(0.02, 0.02, 0.04, 0.92))
	var inner := r.grow(-4.0)
	var _fill := func(f: float, top: Color, bot: Color) -> void:
		if f <= 0.001:
			return
		var w := inner.size.x * clampf(f, 0.0, 1.0)
		var x0 := inner.position.x if dir > 0 else inner.end.x - w
		var x1 := x0 + w
		var pts := PackedVector2Array([Vector2(x0 + maxf(0, s), inner.position.y), Vector2(x1 + minf(0, s), inner.position.y),
			Vector2(x1 - maxf(0, s), inner.end.y), Vector2(x0 - minf(0, s), inner.end.y)])
		ci.draw_polygon(pts, _vertical_colors(pts, inner, top, bot))
	if chip >= 0.0:
		_fill.call(chip, Color("ff6a4a"), Color("a0201a"))
	_fill.call(frac, fill_top, fill_bot)
	# glossy highlight band
	ci.draw_line(Vector2(inner.position.x + absf(s), inner.position.y + 4), Vector2(inner.end.x - absf(s), inner.position.y + 4), Color(1, 1, 1, 0.22), 3.0)
	var outline := frame.duplicate()
	outline.append(outline[0])
	ci.draw_polyline(outline, trim, 2.5)


## Big outlined display text with a coloured glow (titles, FIGHT!, K.O., combo counter).
static func shout(ci: CanvasItem, pos: Vector2, text: String, size: int, col: Color, glow: Color, align_center := true) -> void:
	var f := display_bold()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos - Vector2(w / 2.0 if align_center else 0.0, 0)
	ci.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.22), Color(glow, 0.35))
	ci.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.09), Color(0, 0, 0, 0.95))
	ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
