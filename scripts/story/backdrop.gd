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
	if bg_id in ["crater", "research_chamber", "forbidden_chamber", "centroid_chamber", "hq_siege", "solar_altar", "training_ground"]:
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


func _graves(w: float, h: float) -> void:
	_grad(Rect2(0, 0, w, h), Color("030305"), Color("0d0f18"))
	var ground := h * 0.74
	draw_rect(Rect2(0, ground, w, h - ground), Color("07080c"))
	for i in 2:
		var x := w * (0.4 + i * 0.2)
		draw_rect(Rect2(x - 40, ground - 130, 80, 130), Color("1b1d26"))
		draw_circle(Vector2(x, ground - 130), 40, Color("1b1d26"))
