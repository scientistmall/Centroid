class_name Ink
extends RefCounted
## The manga look of every menu, button and HUD frame, matching the story pages: black ink
## outlines, slanted panels, hard offset shadows, screentone dots, speed lines and comic
## lettering. Drawing helpers here; StyleBoxInk puts the same look on any Button or Panel.

const INK := Color("0b0b10")
const PAPER := Color("f3eee2")
const PAPER_SHADE := Color("d9d2c1")
const NIGHT := Color("15151f")        # dark panels (the story's night pages)
const NIGHT_LOW := Color("0c0c13")
const RED := Color("e8343c")          # action accent (manga red)
const GOLD := Color("f5c84c")
const SKY := Color("6fd2ff")

static var _letter: Font
static var _label: Font


## Comic lettering for buttons, titles and shouts.
static func letter_font() -> Font:
	if _letter == null:
		_letter = load("res://assets/fonts/Bangers-Regular.woff2")
	return _letter


## Heavy anime-UI gothic for labels and small text.
static func label_font() -> Font:
	if _label == null:
		_label = load("res://assets/fonts/ZenKakuGothicNew-Black.woff2")
	return _label


## A parallelogram: the top edge leans right by `slant` px (negative leans left).
static func slanted(r: Rect2, slant: float) -> PackedVector2Array:
	var s := slant * 0.5
	return PackedVector2Array([
		Vector2(r.position.x + s + absf(s), r.position.y),
		Vector2(r.end.x + s - absf(s), r.position.y),
		Vector2(r.end.x - s - absf(s), r.end.y),
		Vector2(r.position.x - s + absf(s), r.end.y)])


static func _inside(pts: PackedVector2Array, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, pts)


## Screentone: a dot grid that grows from nothing to `max_r` across the shape (toward `toward`,
## 0..1 in the shape's box), clipped to the polygon. The classic manga shading.
static func tone_dots(pts: PackedVector2Array, r: Rect2, col: Color, step := 9.0, max_r := 2.6,
		toward := Vector2(1, 1)) -> Array:
	var out := []
	var y := r.position.y + step * 0.5
	var row := 0
	while y < r.end.y:
		var x := r.position.x + step * (0.5 if row % 2 == 0 else 1.0)
		while x < r.end.x:
			var u := Vector2((x - r.position.x) / maxf(1.0, r.size.x), (y - r.position.y) / maxf(1.0, r.size.y))
			var k := clampf((u.dot(toward.normalized()) - 0.35) / 0.65, 0.0, 1.0)
			var rad := max_r * k
			if rad > 0.45 and _inside(pts, Vector2(x, y)):
				out.append([Vector2(x, y), rad])
			x += step
		y += step * 0.866
		row += 1
	return out


## A manga panel / button body on a CanvasItem.
static func panel(ci: CanvasItem, r: Rect2, fill := NIGHT, accent := Color(0, 0, 0, 0), slant := 0.0,
		shadow := 8.0, tone := true, frame := Color.WHITE) -> void:
	var pts := slanted(r, slant)
	if shadow > 0.0:
		var sp := PackedVector2Array()
		for v in pts:
			sp.append(v + Vector2(shadow, shadow))
		ci.draw_colored_polygon(sp, Color(0, 0, 0, 0.85))
	ci.draw_colored_polygon(pts, fill)
	if tone:
		var dot := INK if fill.get_luminance() > 0.5 else Color(1, 1, 1)
		for d in tone_dots(pts, r, dot, 10.0, 2.4):
			ci.draw_circle(d[0], d[1], Color(dot, 0.16 if fill.get_luminance() > 0.5 else 0.07))
	if accent.a > 0.0:
		var bar := Rect2(r.position, Vector2(minf(14.0, r.size.x * 0.06), r.size.y))
		ci.draw_colored_polygon(slanted(bar, slant), accent)
	var ol := pts.duplicate()
	ol.append(pts[0])
	ci.draw_polyline(ol, INK, 6.0, true)
	if frame.a > 0.0:
		var inner := slanted(r.grow(-6.0), slant)
		inner.append(inner[0])
		ci.draw_polyline(inner, Color(frame, 0.85 * frame.a), 2.0, true)


## Radiating speed lines (focus lines) around `c`, between radius r0 and r1.
static func speed_lines(ci: CanvasItem, c: Vector2, r0: float, r1: float, n: int, col: Color, seed_v := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.04, 0.04)
		var w := rng.randf_range(0.004, 0.014)
		var s := r0 * rng.randf_range(1.0, 1.35)
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		ci.draw_colored_polygon(PackedVector2Array([c + dir * s, c + (dir + side * w) * r1, c + (dir - side * w) * r1]), col)


## Big comic lettering: white fill, thick black ink outline, a coloured outer stroke and a
## hard drop shadow, slightly tilted like a manga sound effect.
static func shout(ci: CanvasItem, pos: Vector2, text: String, size: int, col := Color.WHITE, stroke := RED,
		align_center := true, tilt := -0.04) -> void:
	var f := letter_font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(-w / 2.0 if align_center else 0.0, 0)
	# untilted text keeps the caller's draw transform (a tilt has to set its own)
	if tilt != 0.0:
		ci.draw_set_transform(pos, tilt, Vector2.ONE)
	else:
		p += pos
	var sh := Vector2(size * 0.06, size * 0.06)
	ci.draw_string_outline(f, p + sh, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.3), Color(0, 0, 0, col.a * 0.9))
	if stroke.a > 0.0:
		ci.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.3), Color(stroke, stroke.a * col.a))
	ci.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.14), Color(INK, col.a))
	ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if tilt != 0.0:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
