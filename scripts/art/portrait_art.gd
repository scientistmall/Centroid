class_name PortraitArt
extends RefCounted
## Coloured anime-style bust portraits drawn as vector shapes ("shadow-anime" style).
## A look comes from data/costumes/<id>.json -> "portrait". Faces 3/4 to the right;
## the caller mirrors for the right-hand slot.
##
## Units: the face is ~1.0 tall, centred on (0, 0). Everything is scaled by `s`.

const LINE := Color("1a1016")
const EXPRESSIONS := ["neutral", "angry", "sad", "shocked", "smile", "determined"]

static var _cache: Dictionary = {}


static func look_for(id: String) -> Dictionary:
	if not _cache.has(id):
		var path := "res://data/costumes/%s.json" % id
		var d := {}
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				d = parsed
		_cache[id] = d
	return _cache[id]


static func has_look(id: String) -> bool:
	return look_for(id).has("portrait")


static func paint(ci: CanvasItem, size: Vector2, look: Dictionary, expr: String, t: float, accent: Color) -> void:
	var s := size.y * 0.30
	var breath := sin(t * 1.8) * 0.012
	var o := Vector2(size.x * 0.5, size.y * 0.37)
	var blink := fmod(t, 4.3) < 0.12
	var skin := Color(look.get("skin", "#e0b090"))
	var skin_sh := skin.darkened(0.28).lerp(Color("5a3a6a"), 0.18)
	var hair := Color(look.get("hair", "#222233"))
	var hair_l := Color(look.get("hair_light", "#556688"))
	var outfit := Color(look.get("outfit", "#202030"))
	var trim := Color(look.get("outfit_trim", accent.to_html()))
	var broad: bool = look.get("build", "") == "broad"
	var style: String = look.get("hair_style", "short")

	var P := func(x: float, y: float) -> Vector2:
		return o + Vector2(x, y) * s

	# soft glow behind the bust
	for i in range(6, 0, -1):
		ci.draw_circle(P.call(0.0, 0.2), s * (0.5 + i * 0.22), Color(accent, 0.025))

	# ---- back hair
	_hair_back(ci, P, s, style, hair, hair_l)

	# ---- shoulders / outfit (breathing moves them slightly)
	var sw := 1.45 if broad else 1.2
	var by := 0.80 + breath
	var body := PackedVector2Array([
		P.call(-sw - 0.1, 2.2), P.call(-sw, 1.15 + breath), P.call(-0.55, by), P.call(0.55, by),
		P.call(sw, 1.1 + breath), P.call(sw + 0.1, 2.2)])
	ci.draw_colored_polygon(body, outfit)
	# shading on the back shoulder
	ci.draw_colored_polygon(PackedVector2Array([
		P.call(-sw - 0.1, 2.2), P.call(-sw, 1.15 + breath), P.call(-0.55, by), P.call(-0.35, 2.2)]), outfit.darkened(0.35))
	# neck
	ci.draw_colored_polygon(PackedVector2Array([
		P.call(-0.15, 0.30), P.call(0.17, 0.30), P.call(0.2, by + 0.05), P.call(-0.18, by + 0.05)]), skin)
	ci.draw_colored_polygon(PackedVector2Array([
		P.call(-0.15, 0.30), P.call(0.17, 0.42), P.call(0.18, 0.55), P.call(-0.17, 0.62)]), skin_sh)
	# collar (V-neck with trim)
	ci.draw_polyline(PackedVector2Array([P.call(-0.55, by), P.call(0.02, by + 0.42), P.call(0.55, by)]), trim, s * 0.035)
	ci.draw_polyline(body, Color(trim, 0.5), s * 0.018)
	_accessory(ci, P, s, look, breath, by)

	# ---- head
	ci.draw_colored_polygon(_ellipse(P.call(-0.02, -0.18), s * 0.45, s * 0.5), skin)  # cranium
	var face := PackedVector2Array([
		P.call(-0.40, -0.40), P.call(0.30, -0.47), P.call(0.42, -0.10), P.call(0.36, 0.18),
		P.call(0.22, 0.38), P.call(0.06, 0.50), P.call(-0.14, 0.42), P.call(-0.34, 0.22), P.call(-0.43, -0.05)])
	ci.draw_colored_polygon(face, skin)
	# cel shadow on the far side + under the cheekbone
	ci.draw_colored_polygon(PackedVector2Array([
		P.call(-0.40, -0.40), P.call(-0.24, -0.38), P.call(-0.30, 0.0), P.call(-0.16, 0.30),
		P.call(-0.14, 0.42), P.call(-0.34, 0.22), P.call(-0.43, -0.05)]), skin_sh)
	# ear
	ci.draw_colored_polygon(_ellipse(P.call(-0.42, 0.02), s * 0.07, s * 0.12), skin_sh)
	# jaw line
	ci.draw_polyline(PackedVector2Array([P.call(0.42, -0.10), P.call(0.36, 0.18), P.call(0.22, 0.38),
		P.call(0.06, 0.50), P.call(-0.14, 0.42)]), Color(LINE, 0.55), s * 0.014)
	if look.get("scar", false):
		ci.draw_line(P.call(0.18, -0.12), P.call(0.32, 0.20), Color("8a4a44"), s * 0.022)
		ci.draw_line(P.call(0.22, -0.02), P.call(0.30, -0.04), Color("8a4a44"), s * 0.016)

	_face_features(ci, P, s, look, expr, blink)

	# ---- front hair
	_hair_front(ci, P, s, style, hair, hair_l)

	# rim light along the lit side
	ci.draw_polyline(PackedVector2Array([P.call(0.30, -0.47), P.call(0.42, -0.10), P.call(0.36, 0.18),
		P.call(0.22, 0.38)]), Color(accent, 0.75), s * 0.016)


# ------------------------------------------------------------------ features

static func _face_features(ci: CanvasItem, P: Callable, s: float, look: Dictionary, expr: String, blink: bool) -> void:
	var eye_col := Color(look.get("eyes", "#6688ff"))
	var tilt := 0.0      # + = inner corners down (angry)
	var open := 1.0
	var iris := 1.0
	var brow_tilt := 0.0
	var brow_y := 0.0
	match expr:
		"angry":
			tilt = 0.05; open = 0.72; brow_tilt = 0.10; brow_y = 0.03
		"determined":
			tilt = 0.025; open = 0.85; brow_tilt = 0.05; brow_y = 0.01
		"sad":
			tilt = -0.04; open = 0.8; brow_tilt = -0.08; brow_y = -0.02
		"shocked":
			open = 1.25; iris = 0.7; brow_y = -0.07
		"smile":
			open = 0.6; brow_y = -0.02
	# far eye (left, narrower) and near eye (right)
	_eye(ci, P, s, Vector2(-0.16, 0.0), 0.17, open, iris, -tilt, eye_col, blink, expr == "smile")
	_eye(ci, P, s, Vector2(0.20, 0.0), 0.21, open, iris, tilt, eye_col, blink, expr == "smile")
	# brows
	var hair := Color(look.get("hair", "#222233")).darkened(0.2)
	ci.draw_line(P.call(-0.30, -0.13 + brow_y - brow_tilt * 0.3), P.call(-0.06, -0.15 + brow_y + brow_tilt), hair, s * 0.035)
	ci.draw_line(P.call(0.08, -0.16 + brow_y + brow_tilt), P.call(0.34, -0.15 + brow_y - brow_tilt * 0.3), hair, s * 0.04)
	# nose
	ci.draw_polyline(PackedVector2Array([P.call(0.10, 0.08), P.call(0.16, 0.20), P.call(0.10, 0.22)]), Color(LINE, 0.45), s * 0.014)
	# mouth
	var m: Vector2 = P.call(0.10, 0.32)
	match expr:
		"angry":
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-0.09, 0.01) * s, m + Vector2(0.08, -0.01) * s,
				m + Vector2(0.06, 0.05) * s, m + Vector2(-0.07, 0.05) * s]), Color("3a1418"))
			ci.draw_line(m + Vector2(-0.08, 0.02) * s, m + Vector2(0.07, 0.0) * s, Color("f0e8e8"), s * 0.018)
		"shocked":
			ci.draw_colored_polygon(_ellipse(m + Vector2(0, 0.02) * s, s * 0.04, s * 0.055), Color("3a1418"))
		"smile":
			ci.draw_polyline(PackedVector2Array([m + Vector2(-0.08, -0.01) * s, m + Vector2(0.0, 0.035) * s,
				m + Vector2(0.08, -0.02) * s]), LINE, s * 0.016)
		"sad":
			ci.draw_polyline(PackedVector2Array([m + Vector2(-0.07, 0.03) * s, m + Vector2(0.0, 0.0) * s,
				m + Vector2(0.07, 0.025) * s]), LINE, s * 0.015)
		_:
			ci.draw_line(m + Vector2(-0.06, 0.0) * s, m + Vector2(0.07, -0.005) * s, LINE, s * 0.015)


static func _eye(ci: CanvasItem, P: Callable, s: float, c: Vector2, w: float, open: float, iris_k: float,
		tilt: float, col: Color, blink: bool, happy: bool) -> void:
	var h := 0.11 * open
	var inner := c + Vector2(-w * 0.5, tilt if c.x > 0 else 0.0)
	var outer := c + Vector2(w * 0.5, 0.0 if c.x > 0 else tilt)
	if c.x < 0:
		inner = c + Vector2(w * 0.5, tilt)
		outer = c + Vector2(-w * 0.5, 0.0)
	if blink or happy:
		# closed / happy eye: a curved lid line
		var mid := (inner + outer) * 0.5 + Vector2(0, 0.02 if happy else 0.0)
		ci.draw_polyline(PackedVector2Array([P.call(inner.x, inner.y), P.call(mid.x, mid.y - (0.04 if happy else 0.0)),
			P.call(outer.x, outer.y)]), LINE, s * 0.03)
		return
	var top := (inner + outer) * 0.5 + Vector2(0, -h)
	var bot := (inner + outer) * 0.5 + Vector2(0, h * 0.7)
	var sclera := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var base: Vector2 = inner.lerp(outer, u)
		sclera.append(P.call(base.x, base.y - sin(u * PI) * h))
	for i in range(12, -1, -1):
		var u2 := i / 12.0
		var base2: Vector2 = inner.lerp(outer, u2)
		sclera.append(P.call(base2.x, base2.y + sin(u2 * PI) * h * 0.7))
	ci.draw_colored_polygon(sclera, Color("f2eef0"))
	# iris + pupil (look slightly toward the facing direction)
	var ic := (inner + outer) * 0.5 + Vector2(0.015, 0.005)
	var ir := w * 0.30 * iris_k
	var iris_poly := _ellipse(P.call(ic.x, ic.y), s * ir, s * minf(ir * 1.25, h * 1.15))
	ci.draw_colored_polygon(iris_poly, col.darkened(0.15))
	ci.draw_colored_polygon(_ellipse(P.call(ic.x, ic.y + 0.012), s * ir * 0.8, s * minf(ir, h) * 0.85), col)
	ci.draw_colored_polygon(_ellipse(P.call(ic.x, ic.y), s * ir * 0.45, s * minf(ir * 0.6, h * 0.6)), Color("0c0810"))
	ci.draw_circle(P.call(ic.x - ir * 0.35, ic.y - ir * 0.45), s * ir * 0.28, Color(1, 1, 1, 0.95))
	ci.draw_circle(P.call(ic.x + ir * 0.35, ic.y + ir * 0.4), s * ir * 0.12, Color(1, 1, 1, 0.8))
	# upper lid (thick) + lower lash
	var lid := PackedVector2Array()
	for i in 13:
		var u3 := i / 12.0
		var b3: Vector2 = inner.lerp(outer, u3)
		lid.append(P.call(b3.x, b3.y - sin(u3 * PI) * h))
	ci.draw_polyline(lid, LINE, s * 0.032)
	ci.draw_line(P.call(outer.x, outer.y), P.call(outer.x + (0.03 if c.x > 0 else -0.03), outer.y - 0.03), LINE, s * 0.025)
	ci.draw_line(P.call(bot.x - w * 0.2, bot.y), P.call(bot.x + w * 0.25, bot.y - 0.01), Color(LINE, 0.5), s * 0.012)


# ------------------------------------------------------------------ hair

static func _hair_back(ci: CanvasItem, P: Callable, s: float, style: String, hair: Color, _hl: Color) -> void:
	match style:
		"spiky":
			var pts := PackedVector2Array()
			var c := Vector2(-0.10, -0.15)
			for i in 15:
				var a := deg_to_rad(150.0 + i * 16.0)
				var r := 0.78 if i % 2 == 0 else 0.52
				pts.append(P.call(c.x + cos(a) * r - 0.06, c.y + sin(a) * r))
			ci.draw_colored_polygon(pts, hair.darkened(0.25))
		"long":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.50, -0.45), P.call(0.10, -0.72), P.call(0.45, -0.40),
				P.call(0.30, 0.6), P.call(-0.2, 1.3), P.call(-0.75, 1.15), P.call(-0.60, 0.2)]), hair.darkened(0.25))
		"tied":
			ci.draw_colored_polygon(_ellipse(P.call(-0.50, -0.42), s * 0.18, s * 0.16), hair.darkened(0.2))
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.55, -0.35), P.call(-0.85, 0.6), P.call(-0.62, 0.9),
				P.call(-0.45, -0.25)]), hair.darkened(0.25))
		_:
			pass


static func _hair_front(ci: CanvasItem, P: Callable, s: float, style: String, hair: Color, hl: Color) -> void:
	match style:
		"spiky":
			var bangs := PackedVector2Array([
				P.call(-0.46, -0.25), P.call(-0.44, -0.58), P.call(-0.10, -0.74), P.call(0.30, -0.66),
				P.call(0.50, -0.38), P.call(0.47, -0.12), P.call(0.36, -0.30), P.call(0.27, -0.02),
				P.call(0.16, -0.30), P.call(0.04, -0.06), P.call(-0.05, -0.32), P.call(-0.20, -0.10),
				P.call(-0.27, -0.34), P.call(-0.40, -0.14)])
			ci.draw_colored_polygon(bangs, hair)
			# top spikes
			for k in 4:
				var bx := -0.30 + k * 0.2
				ci.draw_colored_polygon(PackedVector2Array([P.call(bx - 0.12, -0.62), P.call(bx - 0.08, -0.95 + k * 0.04),
					P.call(bx + 0.1, -0.64)]), hair)
			# short strand highlights following the bangs
			for hs in [[0.22, -0.56, 0.32, -0.30], [0.06, -0.62, 0.14, -0.36], [-0.12, -0.62, -0.06, -0.40]]:
				ci.draw_line(P.call(hs[0], hs[1]), P.call(hs[2], hs[3]), Color(hl, 0.75), s * 0.022)
		"mohawk":
			# shaved sides (stubble)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.46, -0.30), P.call(-0.38, -0.55), P.call(0.25, -0.62),
				P.call(0.40, -0.42), P.call(0.30, -0.45), P.call(-0.30, -0.40)]), Color(hair, 0.55))
			# tall crest sweeping back, spikes rising from the skull
			# base band along the skull, then separate spikes (simple shapes always fill)
			ci.draw_colored_polygon(PackedVector2Array([
				P.call(0.32, -0.50), P.call(0.20, -0.72), P.call(-0.30, -0.76), P.call(-0.60, -0.52),
				P.call(-0.56, -0.32), P.call(-0.30, -0.50), P.call(0.0, -0.58)]), hair)
			for sp in [[0.30, -0.56, 0.26, -0.88, 0.10, -0.66], [0.12, -0.64, 0.06, -1.06, -0.10, -0.68],
					[-0.08, -0.68, -0.18, -1.10, -0.32, -0.70], [-0.28, -0.70, -0.44, -1.00, -0.54, -0.58],
					[-0.48, -0.58, -0.70, -0.76, -0.58, -0.36]]:
				var tri := PackedVector2Array([P.call(sp[0], sp[1]), P.call(sp[2], sp[3]), P.call(sp[4], sp[5])])
				ci.draw_colored_polygon(tri, hair)
				ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), Color(hl, 0.55), s * 0.014)
			for hs in [[0.14, -0.66, 0.24, -0.84], [-0.06, -0.70, 0.04, -1.0], [-0.28, -0.70, -0.18, -1.04], [-0.48, -0.60, -0.43, -0.94]]:
				ci.draw_line(P.call(hs[0], hs[1]), P.call(hs[2], hs[3]), Color(hl, 0.8), s * 0.022)
		"long", "tied":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.48, -0.10), P.call(-0.46, -0.55), P.call(-0.05, -0.74),
				P.call(0.36, -0.62), P.call(0.50, -0.30), P.call(0.40, -0.20), P.call(0.22, -0.40), P.call(0.02, -0.20),
				P.call(-0.18, -0.40), P.call(-0.36, -0.20)]), hair)
			ci.draw_polyline(PackedVector2Array([P.call(-0.30, -0.58), P.call(0.0, -0.66), P.call(0.30, -0.56)]), Color(hl, 0.7), s * 0.028)
		_:
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.47, -0.18), P.call(-0.45, -0.56), P.call(-0.05, -0.70),
				P.call(0.36, -0.60), P.call(0.48, -0.34), P.call(0.30, -0.36), P.call(0.10, -0.26), P.call(-0.15, -0.34),
				P.call(-0.35, -0.24)]), hair)
			ci.draw_polyline(PackedVector2Array([P.call(-0.28, -0.56), P.call(0.0, -0.63), P.call(0.28, -0.54)]), Color(hl, 0.7), s * 0.028)


static func _accessory(ci: CanvasItem, P: Callable, s: float, look: Dictionary, breath: float, by: float) -> void:
	var acc: String = look.get("accessory", "")
	var col := Color(look.get("accessory_color", "#cccccc"))
	match acc:
		"scarf":
			# trailing end first (behind the wrap), gently swaying
			var sw := breath * 3.0
			ci.draw_colored_polygon(PackedVector2Array([
				P.call(-0.28, by + 0.02), P.call(-0.02, by + 0.10), P.call(-0.12, 1.25), P.call(-0.30 + sw, 1.75),
				P.call(-0.52 + sw, 1.78), P.call(-0.42 + sw, 1.30)]), col.darkened(0.18))
			ci.draw_line(P.call(-0.16, by + 0.25), P.call(-0.36 + sw, 1.65), col.darkened(0.32), s * 0.016)
			# the wrap: rounded band with soft curved edges
			var wrap := PackedVector2Array()
			for i in 9:
				var u := i / 8.0
				wrap.append(P.call(lerpf(-0.50, 0.54, u), lerpf(0.50, 0.58, u) - sin(u * PI) * 0.05))
			for i in range(8, -1, -1):
				var u2 := i / 8.0
				wrap.append(P.call(lerpf(-0.52, 0.56, u2), lerpf(by + 0.06, by + 0.10, u2) + sin(u2 * PI) * 0.08))
			ci.draw_colored_polygon(wrap, col)
			# folds
			for f in 3:
				var fy := 0.60 + f * 0.09
				var fold := PackedVector2Array()
				for i in 7:
					var u3 := i / 6.0
					fold.append(P.call(lerpf(-0.42, 0.46, u3), fy + sin(u3 * PI) * 0.05 + u3 * 0.03))
				ci.draw_polyline(fold, col.darkened(0.25), s * 0.014)
		"pauldron":
			# three overlapping curved armour plates over the shoulder
			var trim_col := Color(look.get("outfit_trim", "#ff4a3d"))
			for k in 3:
				var c: Vector2 = P.call(-0.86 - k * 0.10, 1.00 + k * 0.17 + breath)
				var plate := PackedVector2Array()
				for i in 13:
					var a := PI + PI * i / 12.0
					plate.append(c + Vector2(cos(a) * 0.46, sin(a) * 0.26) * s)
				plate.append(c + Vector2(0.40, 0.10) * s)
				plate.append(c + Vector2(-0.40, 0.12) * s)
				ci.draw_colored_polygon(plate, col.lightened(0.10 - k * 0.06))
				ci.draw_polyline(plate.slice(0, 13), trim_col, s * 0.022)
				ci.draw_circle(c + Vector2(0.0, -0.18) * s, s * 0.025, Color("8a7a70"))


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
