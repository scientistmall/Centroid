class_name Backdrop
extends Control
## Procedurally painted placeholder backgrounds (until real art exists).
## Set `bg_id` to one of the ids handled in `_draw()`.

@export var bg_id: String = "black":
	set(v):
		bg_id = v
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	# Only a few backdrops animate (glowing stones, flames).
	if bg_id in ["crater", "research_chamber", "forbidden_chamber", "centroid_chamber", "hq_siege", "solar_altar", "training_ground", "silent_forest", "underground_sanctuary", "title"]:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	match bg_id:
		"training_ground": _training_ground(w, h)
		"hq_night": _hq_night(w, h)
		"crater": _crater(w, h)
		"research_chamber": _chamber(w, h, false)
		"research_dark": _chamber(w, h, true)
		"balcony_sunset": _balcony(w, h)
		"forbidden_chamber": _altar_room(w, h, Color("2a1240"), Color("9b6bff"))
		"centroid_chamber": _altar_room(w, h, Color("1a1030"), Color("b48cff"))
		"hq_siege": _hq_siege(w, h)
		"solar_altar": _solar_altar(w, h)
		"graves": _graves(w, h)
		"silent_forest": _silent_forest(w, h)
		"broken_pass": _broken_pass(w, h)
		"underground_sanctuary": _sanctuary(w, h)
		"title": _title(w, h)
		_: draw_rect(Rect2(0, 0, w, h), Color.BLACK)


# ---------- helpers ----------

func _grad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _stars(w: float, h: float, count: int, alpha: float, seed_val: int = 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in count:
		var p := Vector2(rng.randf() * w, rng.randf() * h)
		var a := alpha * (0.4 + 0.6 * rng.randf())
		draw_circle(p, rng.randf_range(1.0, 2.6), Color(1, 1, 1, a))


func _trees(w: float, base_y: float, height: float, col: Color, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var x := -40.0
	while x < w + 40:
		var th := height * rng.randf_range(0.6, 1.1)
		var tw := th * 0.45
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - tw / 2, base_y), Vector2(x, base_y - th), Vector2(x + tw / 2, base_y)]), col)
		x += rng.randf_range(tw * 0.35, tw * 0.8)
	draw_rect(Rect2(0, base_y, w, size.y - base_y), col)


func _pillar(x: float, top: float, bottom: float, width: float, col: Color, broken: bool) -> void:
	var t := top + (width * 0.6 if broken else 0.0)
	draw_rect(Rect2(x - width / 2, t, width, bottom - t), col)
	draw_rect(Rect2(x - width * 0.65, bottom - 24, width * 1.3, 24), col.darkened(0.2))
	if broken:
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - width / 2, t), Vector2(x - width * 0.1, t - width * 0.5),
			Vector2(x + width * 0.2, t - width * 0.1), Vector2(x + width / 2, t - width * 0.7),
			Vector2(x + width / 2, t)]), col)
	else:
		draw_rect(Rect2(x - width * 0.65, top - 20, width * 1.3, 20), col.darkened(0.2))


func _stone(center: Vector2, r: float, glow: Color, dark: bool = false) -> void:
	var pulse := 0.6 + 0.4 * sin(_time * 2.0)
	for i in range(6, 0, -1):
		draw_circle(center, r + i * 10.0 * pulse, Color(glow.r, glow.g, glow.b, 0.05))
	draw_circle(center, r, Color("08080c"))
	var lc := glow if not dark else Color("120018")
	draw_line(center + Vector2(-r * 0.8, -r * 0.2), center + Vector2(r * 0.8, r * 0.2), lc.lightened(0.3), 3.0)


# ---------- scenes ----------

func _training_ground(w: float, h: float) -> void:
	_grad(Rect2(0, 0, w, h * 0.75), Color("05060c"), Color("10142a"))
	_stars(w, h * 0.6, 60, 0.25, 11)
	var ground := h * 0.72
	for i in 6:
		var px := w * (0.08 + i * 0.17)
		_pillar(px, h * 0.22 + (i % 2) * 40, ground, 70, Color("161a28"), i % 3 == 1)
	_grad(Rect2(0, ground, w, h - ground), Color("1c1e2a"), Color("0a0b10"))
	# steps
	for s in 3:
		draw_rect(Rect2(w * 0.38 - s * 30, ground - 36 + s * 12, w * 0.24 + s * 60, 12), Color("23263a"))
	# broken practice swords
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 9:
		var p := Vector2(rng.randf() * w, ground + 20 + rng.randf() * (h - ground - 40))
		var a := rng.randf() * TAU
		draw_line(p, p + Vector2(cos(a), sin(a) * 0.3) * rng.randf_range(40, 90), Color("3b2f22"), 5)
	# lantern glow
	var flicker := 0.85 + 0.15 * sin(_time * 7.0) * sin(_time * 3.1)
	for i in range(8, 0, -1):
		draw_circle(Vector2(w * 0.2, ground - 60), i * 22 * flicker, Color(1, 0.7, 0.3, 0.025))


func _hq_night(w: float, h: float) -> void:
	_grad(Rect2(0, 0, w, h), Color("060a1c"), Color("1a2a4a"))
	_stars(w, h * 0.7, 180, 0.8, 21)
	draw_circle(Vector2(w * 0.8, h * 0.18), 46, Color("e8ecff"))
	_trees(w, h * 0.78, 160, Color("070b14"), 5)
	var bx := w * 0.12
	var by := h * 0.78
	draw_rect(Rect2(bx, by - 300, 420, 300), Color("0b0f1a"))
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 30, by - 300), Vector2(bx + 210, by - 420), Vector2(bx + 450, by - 300)]), Color("0b0f1a"))
	for i in 4:
		draw_rect(Rect2(bx + 40 + i * 95, by - 230, 40, 60), Color(1, 0.8, 0.45, 0.8))
	draw_rect(Rect2(0, by, w, h - by), Color("05070d"))


func _crater(w: float, h: float) -> void:
	_grad(Rect2(0, 0, w, h), Color("05060f"), Color("1d1424"))
	_stars(w, h * 0.5, 120, 0.7, 33)
	_trees(w, h * 0.55, 220, Color("06080c"), 9)
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color("140d10"))
	var c := Vector2(w * 0.5, h * 0.75)
	draw_set_transform(c, 0, Vector2(1, 0.32))
	draw_circle(Vector2.ZERO, 520, Color("2a1410"))
	draw_circle(Vector2.ZERO, 440, Color("3d1a0e"))
	draw_circle(Vector2.ZERO, 300, Color("1a0c08"))
	draw_set_transform(Vector2.ZERO)
	_stone(c + Vector2(0, -30), 46, Color("ffe7a0"))


func _chamber(w: float, h: float, dark: bool) -> void:
	_grad(Rect2(0, 0, w, h), Color("1e1a22"), Color("0f0d12"))
	var win := Rect2(w * 0.62, h * 0.12, w * 0.22, h * 0.42)
	draw_rect(win, Color("0a0a12") if dark else Color("fff1c8"))
	if not dark:
		draw_colored_polygon(PackedVector2Array([win.position, Vector2(win.end.x, win.position.y), Vector2(w * 0.55, h), Vector2(w * 0.2, h)]), Color(1, 0.95, 0.75, 0.08))
	draw_rect(Rect2(win.position.x + win.size.x / 2 - 4, win.position.y, 8, win.size.y), Color("2a2430"))
	for i in 7:
		draw_line(Vector2(0, h * 0.1 + i * 120), Vector2(w, h * 0.1 + i * 120), Color(0, 0, 0, 0.25), 2)
	# Asterite pedestal
	var p := Vector2(w * 0.3, h * 0.72)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-90, 0), p + Vector2(-60, -150), p + Vector2(60, -150), p + Vector2(90, 0)]), Color("1f7a4a"))
	draw_rect(Rect2(p.x - 110, p.y, 220, 30), Color("166038"))
	_stone(p + Vector2(0, -190), 34, Color("7cffb0"), dark)
	draw_rect(Rect2(0, h * 0.82, w, h * 0.18), Color("141118"))
	if dark:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))


func _balcony(w: float, h: float) -> void:
	_grad(Rect2(0, 0, w, h * 0.6), Color("2b1a3a"), Color("ff8a4a"))
	draw_circle(Vector2(w * 0.7, h * 0.55), 90, Color("ffd27a"))
	_grad(Rect2(0, h * 0.55, w, h * 0.45), Color("3a1e1e"), Color("140a10"))
	_trees(w, h * 0.62, 90, Color("1a0e14"), 4)
	draw_rect(Rect2(0, h * 0.62, w, h * 0.38), Color("1a0e14"))
	draw_rect(Rect2(0, h * 0.78, w, 14), Color("0c070a"))
	var x := 0.0
	while x < w:
		draw_rect(Rect2(x, h * 0.78, 12, h * 0.22), Color("0c070a"))
		x += 70


func _altar_room(w: float, h: float, base: Color, glow: Color) -> void:
	_grad(Rect2(0, 0, w, h), base.darkened(0.5), base)
	for i in 5:
		_pillar(w * (0.1 + i * 0.2), h * 0.08, h * 0.8, 80, base.darkened(0.6), false)
	var p := Vector2(w * 0.5, h * 0.66)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-160, 120), p + Vector2(-90, 0), p + Vector2(90, 0), p + Vector2(160, 120)]), Color("1f5a3e"))
	_stone(p + Vector2(0, -50), 40, glow)
	draw_rect(Rect2(0, h * 0.8, w, h * 0.2), base.darkened(0.7))


func _hq_siege(w: float, h: float) -> void:
	_grad(Rect2(0, 0, w, h), Color("12040a"), Color("4a1208"))
	var by := h * 0.8
	for i in 5:
		var bw := 180.0 + (i % 2) * 60
		var bh := 220.0 + (i % 3) * 90
		draw_rect(Rect2(w * 0.05 + i * w * 0.19, by - bh, bw, bh), Color("0a0406"))
	for i in 14:
		var fx := fmod(i * 173.0, w)
		var fh := 40 + 30 * sin(_time * 5 + i)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 20, by), Vector2(fx, by - fh), Vector2(fx + 20, by)]), Color(1, 0.45, 0.1, 0.8))
	draw_rect(Rect2(0, by, w, h - by), Color("080305"))


func _solar_altar(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color("020203"))
	_stars(w, h * 0.5, 30, 0.15, 77)
	var p := Vector2(w * 0.5, h * 0.7)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-300, 200), p + Vector2(-140, -120), p + Vector2(140, -120), p + Vector2(300, 200)]), Color("0f3a28"))
	_stone(p + Vector2(0, -180), 50, Color("6a3cff"), true)


func _silent_forest(w: float, h: float) -> void:
	# No moon, no stars worth the name: the trees are fading without sunlight.
	_grad(Rect2(0, 0, w, h), Color("040507"), Color("10141a"))
	_stars(w, h * 0.4, 14, 0.12, 51)
	var ground := h * 0.74
	var rng := RandomNumberGenerator.new()
	for layer in 3:
		rng.seed = 100 + layer
		var col := Color("0b0e12").lerp(Color("1a2026"), 1.0 - layer / 2.0)
		var x := -60.0 + layer * 70.0
		while x < w + 60:
			var tw := rng.randf_range(16, 34) * (1.0 + layer * 0.5)
			var top := ground - rng.randf_range(380, 620) * (0.7 + layer * 0.2)
			draw_rect(Rect2(x - tw / 2, top, tw, ground - top + 10), col)
			# bare branches
			for b in 4:
				var by := top + rng.randf_range(20, (ground - top) * 0.55)
				var s := -1.0 if b % 2 == 0 else 1.0
				var len := rng.randf_range(50, 130) * (1.0 + layer * 0.3)
				draw_line(Vector2(x, by), Vector2(x + s * len, by - len * 0.6), col, maxf(3.0, tw * 0.25))
			x += rng.randf_range(160, 320) / (1.0 + layer * 0.4)
	draw_rect(Rect2(0, ground, w, h - ground), Color("07090c"))
	# drifting mist bands
	for i in 5:
		var y := ground - 120 + i * 45
		var drift := fmod(_time * (14.0 + i * 6.0), w + 800)
		for k in 6:
			var cx := fmod(k * 520.0 + drift, w + 800) - 400
			draw_set_transform(Vector2(cx, y), 0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, 300, Color(0.7, 0.75, 0.82, 0.045))
			draw_set_transform(Vector2.ZERO)


func _broken_pass(w: float, h: float) -> void:
	# A ruined mountain passage under the dark sky.
	_grad(Rect2(0, 0, w, h), Color("07060a"), Color("1c1820"))
	_stars(w, h * 0.35, 25, 0.18, 61)
	var ground := h * 0.74
	# far peaks
	var pts := PackedVector2Array([Vector2(0, ground)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var x := 0.0
	while x <= w:
		pts.append(Vector2(x, h * rng.randf_range(0.28, 0.45)))
		x += rng.randf_range(120, 260)
	pts.append(Vector2(w, h * 0.35))
	pts.append(Vector2(w, ground))
	draw_colored_polygon(pts, Color("16121a"))
	var ridge := pts.slice(1, pts.size() - 1)
	draw_polyline(ridge, Color(0.45, 0.38, 0.5, 0.35), 3.0)
	# cliff walls on both sides
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.16, 0), Vector2(w * 0.22, h * 0.35),
		Vector2(w * 0.12, h * 0.55), Vector2(w * 0.18, ground), Vector2(0, ground)]), Color("0b090d"))
	draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w * 0.82, 0), Vector2(w * 0.78, h * 0.3),
		Vector2(w * 0.88, h * 0.5), Vector2(w * 0.8, ground), Vector2(w, ground)]), Color("0b090d"))
	# cracked road
	_grad(Rect2(0, ground, w, h - ground), Color("221c1a"), Color("0b0908"))
	for i in 6:
		var cx := w * (0.2 + i * 0.12)
		draw_polyline(PackedVector2Array([Vector2(cx, ground + 10), Vector2(cx + 30, ground + 60),
			Vector2(cx + 5, ground + 120), Vector2(cx + 40, h)]), Color(0, 0, 0, 0.6), 3.0)
	# boulders and fragments of the broken blocking stone
	rng.seed = 7
	for i in 9:
		var bx := rng.randf_range(w * 0.05, w * 0.95)
		var br := rng.randf_range(18, 55)
		var by := ground + rng.randf_range(25, 150)
		draw_set_transform(Vector2(bx, by), 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, br, Color("2a2324"))
		draw_arc(Vector2.ZERO, br, PI * 1.1, PI * 1.6, 12, Color(0.6, 0.5, 0.45, 0.3), 3.0)
		draw_set_transform(Vector2.ZERO)


func _sanctuary(w: float, h: float) -> void:
	# Underground chamber once used to keep medicines and supplies.
	_grad(Rect2(0, 0, w, h), Color("0c0a0e"), Color("1a1518"))
	var ground := h * 0.74
	# vaulted ceiling arches
	for i in 5:
		var cx := w * (0.1 + i * 0.2)
		draw_arc(Vector2(cx, h * 0.32), w * 0.11, PI, TAU, 24, Color("231d22"), 26.0)
		draw_rect(Rect2(cx - w * 0.11 - 13, h * 0.32, 26, ground - h * 0.32), Color("1f191e"))
	# stone block lines
	for r in 7:
		var y := h * 0.36 + r * 52.0
		draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.25), 2.0)
	# supply shelves with jars and boxes
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	for s in 3:
		var sx := w * (0.2 + s * 0.27)
		for row in 3:
			var sy := h * 0.42 + row * 70.0
			draw_rect(Rect2(sx - 110, sy, 220, 8), Color("3a2d24"))
			var x := sx - 100.0
			while x < sx + 90.0:
				var jw := rng.randf_range(16, 30)
				var jh := rng.randf_range(20, 46)
				draw_rect(Rect2(x, sy - jh, jw, jh), Color("2a2229"))
				x += jw + rng.randf_range(4, 14)
	# the crystal necklace glint on a shelf
	var glint := Vector2(w * 0.47, h * 0.42 + 140.0 - 12.0)
	var pulse := 0.6 + 0.4 * sin(_time * 2.2)
	for i in range(5, 0, -1):
		draw_circle(glint, i * 6.0 * pulse, Color(1.0, 0.6, 0.8, 0.05))
	draw_circle(glint + Vector2(-6, 0), 4, Color(1.0, 0.8, 0.9, 0.9))
	draw_circle(glint + Vector2(6, 0), 4, Color(1.0, 0.8, 0.9, 0.9))
	# dim lantern
	var fl := 0.85 + 0.15 * sin(_time * 6.0) * sin(_time * 2.7)
	for i in range(7, 0, -1):
		draw_circle(Vector2(w * 0.86, h * 0.3), i * 20.0 * fl, Color(1, 0.65, 0.3, 0.03))
	draw_circle(Vector2(w * 0.86, h * 0.3), 8, Color(1, 0.8, 0.5, 0.9))
	# floor
	_grad(Rect2(0, ground, w, h - ground), Color("1d171a"), Color("0a0809"))
	for i in 10:
		draw_line(Vector2(w * i / 10.0, ground), Vector2(w * i / 10.0 - 120, h), Color(0, 0, 0, 0.3), 2.0)


## Main menu wallpaper: eclipse, the Centroid, guardians facing traitors.
const TITLE_GUARDIANS := [["kael", "sword"], ["mira", "flex_blade"], ["tala", "spear"], ["darin", "gauntlets"],
	["iren", "daggers"], ["lyra", "bow"], ["oren", "gauntlets"]]
const TITLE_TRAITORS := [["thane", "twin_swords"], ["rhex", "axe"], ["vaska", "twin_swords"], ["mael", "gauntlets"],
	["nyra", "whip"], ["zerin", "spear"], ["corvin", "crystal_blades"]]


func _title(w: float, h: float) -> void:
	_grad(Rect2(0, 0, w, h), Color("02030a"), Color("0d0b1c"))
	_stars(w, h * 0.8, 160, 0.6, 3)
	var c := Vector2(w * 0.5, h * 0.36)
	var r := h * 0.2
	# corona rays slowly turning
	for i in 90:
		var a := i * TAU / 90.0 + _time * 0.03
		var len := r * (1.35 + 0.35 * sin(i * 7.3) + 0.08 * sin(_time * 0.8 + i))
		draw_line(c + Vector2(cos(a), sin(a)) * r * 1.02, c + Vector2(cos(a), sin(a)) * len,
			Color(1.0, 0.86, 0.6, 0.10 + 0.06 * sin(i * 3.1)), 2.0)
	for i in range(10, 0, -1):
		draw_circle(c, r * (1.0 + i * 0.05), Color(1.0, 0.8, 0.55, 0.018))
	draw_circle(c, r, Color("010104"))
	draw_arc(c, r, 0, TAU, 96, Color(1.0, 0.92, 0.75, 0.85), 3.0)
	# the Centroid: a black stone with a bright and a dark half, slowly turning
	var sc := Vector2(w * 0.5, h * 0.62)
	var turn := sin(_time * 0.4) * 0.6
	for i in range(8, 0, -1):
		draw_circle(sc, 40.0 + i * 9.0, Color(0.55, 0.42, 1.0, 0.03))
	draw_set_transform(sc, turn * 0.3, Vector2(1.0, 0.82))
	draw_circle(Vector2.ZERO, 46, Color("07060c"))
	draw_set_transform(Vector2.ZERO)
	var d := Vector2(cos(turn), sin(turn) * 0.3)
	draw_line(sc - d * 40, sc + d * 40, Color(1, 0.95, 0.8, 0.95), 3.0)
	draw_line(sc - d * 40 + Vector2(0, 4), sc + d * 40 + Vector2(0, 4), Color(0.35, 0.1, 0.6, 0.9), 3.0)
	# horizon
	var ground := h * 0.83
	draw_colored_polygon(PackedVector2Array([Vector2(0, ground), Vector2(w * 0.3, ground - 22), Vector2(w * 0.5, ground - 8),
		Vector2(w * 0.72, ground - 26), Vector2(w, ground), Vector2(w, h), Vector2(0, h)]), Color("040408"))
	# guardians (left, facing right) and traitors (right, facing left)
	var chars := StoryParser.characters()
	for side in 2:
		var group: Array = TITLE_GUARDIANS if side == 0 else TITLE_TRAITORS
		for i in group.size():
			var id: String = group[i][0]
			var col := Color(chars.get(id, {}).get("color", "#ffffff"))
			var depth := 1.0 - i * 0.07
			var x := w * (0.08 + i * 0.045) if side == 0 else w * (0.92 - i * 0.045)
			var y := ground + 6 - i * 3
			draw_set_transform(Vector2(x, y), 0.0, Vector2(0.62, 0.62) * depth)
			var pose := Poses.idle_breath(_time + i * 0.7)
			FighterPainter.paint(self, pose, 1 if side == 0 else -1, Color(col, 0.75 * depth), group[i][1], "", _time, 0.0, false)
			draw_set_transform(Vector2.ZERO)
	# drifting embers
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 40:
		var x0 := rng.randf() * w
		var spd := rng.randf_range(12, 40)
		var y0 := fmod(rng.randf() * h - _time * spd, h)
		if y0 < 0:
			y0 += h
		draw_circle(Vector2(x0 + sin(_time + i) * 10.0, y0), rng.randf_range(1.5, 3.0), Color(1.0, 0.75, 0.45, 0.35))


func _graves(w: float, h: float) -> void:
	_grad(Rect2(0, 0, w, h), Color("030305"), Color("0d0f18"))
	var ground := h * 0.74
	draw_rect(Rect2(0, ground, w, h - ground), Color("07080c"))
	for i in 2:
		var x := w * (0.4 + i * 0.2)
		draw_rect(Rect2(x - 40, ground - 130, 80, 130), Color("1b1d26"))
		draw_circle(Vector2(x, ground - 130), 40, Color("1b1d26"))
