class_name Metal
extends RefCounted
## Drawing helpers for panels, bars and display lettering used across the HUD and menus.
## (Named for the first, heavy-metal look; they now draw the manga ink style of Ink: flat
## cel-shaded fills, thick ink outlines, hard shadows, screentone and comic lettering.)

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
		_display = Ink.letter_font()
	return _display


static func display_bold() -> Font:
	if _display_bold == null:
		_display_bold = Ink.letter_font()
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


## A manga panel: hard shadow, flat fill with screentone, thick ink outline and an inner
## hairline in `trim` (gold / cyan / the fighter's colour mark what the panel is).
static func panel(ci: CanvasItem, r: Rect2, trim: Color, cut := 18.0, top := GUNMETAL_TOP, bot := GUNMETAL_BOT,
		glow := 0.6, cuts := [true, false, true, false]) -> void:
	var light := top.get_luminance() > 0.5
	var fill: Color = Ink.PAPER if light else Ink.NIGHT
	var pts := chamfer(r, cut, cuts)
	var sh := PackedVector2Array()
	for v in pts:
		sh.append(v + Vector2(8, 8))
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.85))
	ci.draw_colored_polygon(pts, fill)
	var dot := Color(Ink.INK, 0.18) if light else Color(1, 1, 1, 0.07)
	for d in Ink.tone_dots(pts, r, dot, 10.0, 2.4):
		ci.draw_circle(d[0], d[1], dot)
	var outline := pts.duplicate()
	outline.append(outline[0])
	ci.draw_polyline(outline, Ink.INK, 6.0, true)
	var inner := chamfer(r.grow(-7.0), maxf(2.0, cut - 4.0), cuts)
	inner.append(inner[0])
	ci.draw_polyline(inner, Color(trim, 0.95), 2.5, true)


## Gold primary-action panel.
static func gold_panel(ci: CanvasItem, r: Rect2, cut := 18.0) -> void:
	panel(ci, r, Ink.RED, cut, Color.WHITE, Color.WHITE, 0.0)


## Slanted (parallelogram) bar, e.g. health bars: an ink frame, a two-tone cel-shaded fill
## (light band on top, hard edge) and screentone on the empty part. `dir` = +1 fills left→right.
static func slant_bar(ci: CanvasItem, r: Rect2, frac: float, fill_top: Color, fill_bot: Color, chip := -1.0,
		dir := 1, slant := 16.0, trim := Color(1, 1, 1, 0.6)) -> void:
	var s := slant * dir
	var frame := PackedVector2Array([r.position + Vector2(maxf(0, s), 0), Vector2(r.end.x + minf(0, s), r.position.y),
		r.end + Vector2(-maxf(0, s), 0), Vector2(r.position.x - minf(0, s), r.end.y)])
	var sh := PackedVector2Array()
	for v in frame:
		sh.append(v + Vector2(5, 5))
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.8))
	ci.draw_colored_polygon(frame, Color("1a1a24"))
	for d in Ink.tone_dots(frame, r, Color(1, 1, 1), 7.0, 1.5, Vector2(0, 1)):
		ci.draw_circle(d[0], d[1], Color(1, 1, 1, 0.08))
	var inner := r.grow(-4.0)
	var _fill := func(f: float, top: Color, bot: Color) -> void:
		if f <= 0.001:
			return
		var w := inner.size.x * clampf(f, 0.0, 1.0)
		var x0 := inner.position.x if dir > 0 else inner.end.x - w
		var x1 := x0 + w
		var pts := PackedVector2Array([Vector2(x0 + maxf(0, s), inner.position.y), Vector2(x1 + minf(0, s), inner.position.y),
			Vector2(x1 - maxf(0, s), inner.end.y), Vector2(x0 - minf(0, s), inner.end.y)])
		ci.draw_colored_polygon(pts, bot)
		# cel shading: a flat light band over the top 40%, hard-edged
		var k := 0.4
		var band := PackedVector2Array([pts[0], pts[1], pts[1].lerp(pts[2], k), pts[0].lerp(pts[3], k)])
		ci.draw_colored_polygon(band, top)
	if chip >= 0.0:
		_fill.call(chip, Color("ff8a6a"), Color("c8261e"))
	_fill.call(frac, fill_top, fill_bot)
	var outline := frame.duplicate()
	outline.append(outline[0])
	ci.draw_polyline(outline, Ink.INK, 5.0, true)
	var hl := PackedVector2Array([inner.position + Vector2(absf(s) * 0.5, 0), Vector2(inner.end.x - absf(s) * 0.5, inner.position.y)])
	ci.draw_line(hl[0], hl[1], Color(trim, trim.a * 0.6), 1.5)


## Big display lettering (titles, FIGHT!, K.O., combo counter, timer): comic letters with an
## ink outline, a coloured outer stroke and a hard shadow.
static func shout(ci: CanvasItem, pos: Vector2, text: String, size: int, col: Color, glow: Color, align_center := true) -> void:
	Ink.shout(ci, pos, text, size, col, Color(glow, 0.95), align_center, 0.0)
