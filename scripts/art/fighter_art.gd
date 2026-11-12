class_name FighterArt
extends RefCounted
## "Shadow-anime" fighter rendering: a dark silhouette built from shaped body parts
## (tapered limbs, torso, boots, hair, scarf, coat tails, armour, detailed weapons)
## with a coloured rim light. Uses the same pose skeleton as FighterPainter.
## The look comes from data/costumes/<id>.json -> "fighter".
##
## `sec` is a secondary-motion lag vector (pixels) that makes cloth and hair trail.

const BODY := Color("07070b")
const BACK := Color("15151d")
const RIM_W := 5.0


static func paint(ci: CanvasItem, p: Dictionary, facing: int, rim: Color, weapon: String, element: String,
		clock: float, flash: float, charged: bool, costume: Dictionary, sec: Vector2, trail: PackedVector2Array) -> void:
	var j := FighterPainter.joints(p, facing)
	var rot := deg_to_rad(p.get("rot", 0.0)) * facing
	if rot != 0.0:
		ci.draw_set_transform(Vector2(0, -20), rot, Vector2.ONE)
	var bulk: float = costume.get("bulk", 1.0)
	var body := BODY.lerp(Color.WHITE, flash)
	var back := BACK.lerp(Color.WHITE, flash)
	var glow := Color(rim, 0.9 if charged else 0.65)

	# weapon smear (drawn first, behind everything)
	if trail.size() >= 4:
		_smear(ci, trail, rim)

	# cloth that hangs behind the body
	_scarf_tail(ci, j, facing, costume, sec, clock)
	_coat(ci, j, facing, costume, sec, clock, body, glow)

	for pass_i in 2:
		var g := RIM_W if pass_i == 0 else 0.0
		var cb := glow if pass_i == 0 else back
		var cf := glow if pass_i == 0 else body
		# back limbs
		_capsule(ci, j["shoulder"], j["elbow_b"], 9.0 * bulk + g, 7.5 * bulk + g, cb)
		_capsule(ci, j["elbow_b"], j["hand_b"], 7.5 * bulk + g, 6.0 * bulk + g, cb)
		_capsule(ci, j["hip"], j["knee_b"], 11.0 * bulk + g, 8.5 * bulk + g, cb)
		_capsule(ci, j["knee_b"], j["foot_b"], 8.5 * bulk + g, 6.5 * bulk + g, cb)
		_boot(ci, j["knee_b"], j["foot_b"], facing, g, cb)
		if weapon in ["twin_swords", "daggers"]:
			_weapon(ci, j["hand_b"], p.get("wpn_b", 120.0), facing, weapon, cb if pass_i == 1 else glow, g, rim, pass_i == 1)
		# torso
		_torso(ci, j, facing, bulk, g, cf)
		# head + hair
		_head(ci, j, facing, costume, g, cf, sec)
		# front leg
		_capsule(ci, j["hip"], j["knee_f"], 12.0 * bulk + g, 9.0 * bulk + g, cf)
		_capsule(ci, j["knee_f"], j["foot_f"], 9.0 * bulk + g, 7.0 * bulk + g, cf)
		_boot(ci, j["knee_f"], j["foot_f"], facing, g, cf)
		# shoulder armour sits over the torso
		if costume.get("shoulder", "none") == "pauldron":
			_pauldron(ci, j, facing, g, cf, rim, pass_i == 1)
		# front arm
		_capsule(ci, j["shoulder"], j["elbow_f"], 9.5 * bulk + g, 8.0 * bulk + g, cf)
		_capsule(ci, j["elbow_f"], j["hand_f"], 8.0 * bulk + g, 6.5 * bulk + g, cf)
		ci.draw_circle(j["hand_f"], 8.0 * bulk + g, cf)
		if weapon != "none":
			_weapon(ci, j["hand_f"], p["wpn"], facing, weapon, cf if pass_i == 1 else glow, g, rim, pass_i == 1)

	# accent details on top of the silhouette (thin, so the silhouette stays dominant)
	_details(ci, j, facing, costume, rim, bulk)
	# glowing eye
	var head: Vector2 = j["head"]
	var eye := head + Vector2(11 * facing, -2)
	ci.draw_circle(eye, 7.0, Color(rim, 0.25))
	ci.draw_line(eye + Vector2(-4 * facing, -1), eye + Vector2(5 * facing, 1), rim.lightened(0.4), 3.0)
	if element != "" and charged:
		FighterPainter._element_fx(ci, j, p, facing, rim, element, clock, weapon)
	ci.draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ parts

## Tapered limb with rounded ends.
## Fills a polygon; if Godot can't triangulate it (self-intersecting pose), uses its convex hull.
static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		pts = Geometry2D.convex_hull(pts)
		if pts.size() < 3:
			return
	ci.draw_colored_polygon(pts, col)


static func _capsule(ci: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.5:
		ci.draw_circle(a, maxf(ra, rb), col)
		return
	var n := Vector2(-d.y, d.x).normalized()
	_fill(ci, PackedVector2Array([a + n * ra, b + n * rb, b - n * rb, a - n * ra]), col)
	ci.draw_circle(a, ra, col)
	ci.draw_circle(b, rb, col)


static func _boot(ci: CanvasItem, knee: Vector2, foot: Vector2, facing: int, g: float, col: Color) -> void:
	var f := foot + Vector2(0, 2)
	_fill(ci, PackedVector2Array([
		f + Vector2(-10 * facing - g, -16 - g), f + Vector2(8 * facing, -18 - g), f + Vector2(26 * facing + g, -4),
		f + Vector2(24 * facing + g, 4 + g), f + Vector2(-12 * facing - g, 4 + g)]), col)
	ci.draw_line(knee.lerp(foot, 0.55), foot, col, 15.0 + g * 2)


static func _torso(ci: CanvasItem, j: Dictionary, facing: int, bulk: float, g: float, col: Color) -> void:
	var up: Vector2 = j["up"]
	var side := Vector2(-up.y, up.x)
	var hip: Vector2 = j["hip"]
	var sh: Vector2 = j["shoulder"]
	var waist := hip.lerp(sh, 0.38)
	var chest := hip.lerp(sh, 0.78)
	var fw := float(facing)
	_fill(ci, PackedVector2Array([
		hip - side * (17 * bulk + g), waist - side * (14 * bulk + g) + side * 2 * fw,
		chest - side * (22 * bulk + g), sh - side * (27 * bulk + g) - up * 2, sh + side * (27 * bulk + g) - up * 2,
		chest + side * (24 * bulk + g), waist + side * (15 * bulk + g), hip + side * (17 * bulk + g)]), col)
	# neck
	ci.draw_line(sh, j["head"], col, 15.0 + g * 2)


static func _head(ci: CanvasItem, j: Dictionary, facing: int, costume: Dictionary, g: float, col: Color, sec: Vector2) -> void:
	var c: Vector2 = j["head"]
	var up: Vector2 = j["up"]
	var fw := float(facing)
	# skull + forward jaw
	ci.draw_circle(c, 24.0 + g, col)
	_fill(ci, PackedVector2Array([
		c + Vector2(-6 * fw, 6), c + Vector2(22 * fw + g * fw, 2), c + Vector2(16 * fw + g * fw, 20 + g),
		c + Vector2(2 * fw, 26 + g), c + Vector2(-12 * fw, 16)]), col)
	var lag := sec * 0.35
	match costume.get("hair_style", "short"):
		"spiky":
			# spikes sweeping back, trailing with motion
			for k in 6:
				var a := deg_to_rad(-100.0 - k * 22.0) if fw > 0 else deg_to_rad(-80.0 + k * 22.0)
				var base := c + Vector2(cos(a), sin(a)) * 18.0
				var tip := c + Vector2(cos(a), sin(a)) * (48.0 + (k % 2) * 10.0) + Vector2(-fw * 14.0, 4.0) + lag
				var nrm := Vector2(-sin(a), cos(a)) * (10.0 + g)
				_fill(ci, PackedVector2Array([base + nrm, tip + (tip - base).normalized() * g, base - nrm]), col)
			# bangs over the brow
			_fill(ci, PackedVector2Array([c + Vector2(-14 * fw, -22 - g), c + Vector2(26 * fw + g * fw, -10),
				c + Vector2(18 * fw, 4 + g), c + Vector2(6 * fw, -8)]), col)
		"mohawk":
			for k in 5:
				var x := 10.0 - k * 9.0
				var base2 := c + Vector2(x * fw, -20)
				var tip2 := base2 + Vector2((-10.0 - k * 4.0) * fw, -30.0 - (k % 2) * 8.0) + lag
				_fill(ci, PackedVector2Array([base2 + Vector2(-6 - g, 4), tip2 + (tip2 - base2).normalized() * g,
					base2 + Vector2(6 + g, 4)]), col)
		"long":
			_fill(ci, PackedVector2Array([c + Vector2(14 * fw, -22 - g), c + Vector2(-26 * fw - g * fw, -10),
				c + Vector2(-34 * fw - g * fw, 40) + lag, c + Vector2(-10 * fw, 44 + g) + lag, c + Vector2(-4 * fw, 6)]), col)
		_:
			_fill(ci, PackedVector2Array([c + Vector2(18 * fw, -18 - g), c + Vector2(-20 * fw - g * fw, -20 - g),
				c + Vector2(-28 * fw - g * fw, 6) + lag, c + Vector2(-8 * fw, 0)]), col)


static func _pauldron(ci: CanvasItem, j: Dictionary, facing: int, g: float, col: Color, rim: Color, solid: bool) -> void:
	var sh: Vector2 = j["shoulder"]
	var fw := float(facing)
	for k in 3:
		var c := sh + Vector2(6 * fw, 4 + k * 10)
		var plate := PackedVector2Array()
		for i in 11:
			var a := PI + PI * i / 10.0
			plate.append(c + Vector2(cos(a) * (32 - k * 4 + g), sin(a) * (16 + g)))
		_fill(ci, plate, col)
		if solid:
			ci.draw_polyline(plate, Color(rim, 0.6), 2.0)


static func _details(ci: CanvasItem, j: Dictionary, facing: int, costume: Dictionary, rim: Color, bulk: float) -> void:
	var up: Vector2 = j["up"]
	var side := Vector2(-up.y, up.x)
	var hip: Vector2 = j["hip"]
	if costume.has("belt"):
		var bc := Color(costume["belt"])
		var b := hip + up * 10.0
		ci.draw_line(b - side * 17 * bulk, b + side * 17 * bulk, Color(bc, 0.85), 5.0)
	if costume.get("bracers", false):
		var e: Vector2 = j["elbow_f"]
		var h: Vector2 = j["hand_f"]
		var m := e.lerp(h, 0.55)
		var d := (h - e).normalized()
		var n := Vector2(-d.y, d.x)
		ci.draw_line(m - n * 9, m + n * 9, Color(rim, 0.8), 4.0)
		ci.draw_line(m + d * 9 - n * 8, m + d * 9 + n * 8, Color(rim, 0.5), 3.0)
	if costume.get("wraps", false):
		for arm in [["elbow_f", "hand_f"], ["elbow_b", "hand_b"]]:
			var e2: Vector2 = j[arm[0]]
			var h2: Vector2 = j[arm[1]]
			var d2 := (h2 - e2).normalized()
			var n2 := Vector2(-d2.y, d2.x)
			for k in 3:
				var m2 := e2.lerp(h2, 0.35 + k * 0.2)
				ci.draw_line(m2 - n2 * 8 - d2 * 3, m2 + n2 * 8 + d2 * 3, Color("6b5650", 0.9), 2.5)
	# collar trim
	var sh: Vector2 = j["shoulder"]
	ci.draw_line(sh - side * 10, sh + up * 4 + side * 8 * float(facing), Color(rim, 0.55), 3.0)


static func _scarf_tail(ci: CanvasItem, j: Dictionary, facing: int, costume: Dictionary, sec: Vector2, clock: float) -> void:
	if not costume.has("scarf"):
		return
	var sc: Dictionary = costume["scarf"]
	var col := Color(sc.get("color", "#dddddd"))
	var length: float = sc.get("length", 140.0)
	var neck: Vector2 = j["shoulder"] + j["up"] * 10.0
	var fw := float(facing)
	var pts_top := PackedVector2Array()
	var pts_bot := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		var flutter := sin(clock * 7.0 - u * 5.0) * 10.0 * u
		var p := neck + Vector2(-fw * length * u, 18.0 * u + flutter) + sec * u * 1.2
		var w := lerpf(9.0, 4.0, u)
		pts_top.append(p + Vector2(0, -w))
		pts_bot.append(p + Vector2(0, w))
	pts_bot.reverse()
	_fill(ci, pts_top + pts_bot, col.darkened(0.15))
	# wrap around the neck
	ci.draw_circle(neck, 13.0, col)


static func _coat(ci: CanvasItem, j: Dictionary, facing: int, costume: Dictionary, sec: Vector2, clock: float, col: Color, glow: Color) -> void:
	var coat: Dictionary = costume.get("coat", {})
	var length: float = coat.get("length", 0.0)
	if length <= 0.0:
		return
	var hip: Vector2 = j["hip"]
	var fw := float(facing)
	var sway := sin(clock * 3.0) * 4.0
	for flap in ([0, 1] if coat.get("split", false) else [0]):
		var off := Vector2(-fw * (6.0 + flap * 12.0), 0)
		var tip := hip + off + Vector2(-fw * (18.0 + flap * 10.0) + sway, length) + sec * 0.8
		var poly := PackedVector2Array([hip + off + Vector2(-8, -6), hip + off + Vector2(10, -6),
			tip + Vector2(8 * fw, 0), tip + Vector2(-10 * fw, -6)])
		var grown := Geometry2D.offset_polygon(poly, RIM_W)
		if grown.size() > 0:
			_fill(ci, grown[0], glow)
		_fill(ci, poly, col)


static func _weapon(ci: CanvasItem, hand: Vector2, deg: float, facing: int, weapon: String, col: Color, g: float, rim: Color, solid: bool) -> void:
	var r := deg_to_rad(deg)
	var d := Vector2(sin(r) * facing, cos(r))
	var n := Vector2(-d.y, d.x)
	match weapon:
		"sword":
			# slightly curved single-edged blade with a round guard and wrapped grip
			var tip := hand + d * 140.0
			var mid := hand.lerp(tip, 0.55) + n * 5.0 * facing
			var blade := PackedVector2Array([hand + d * 14 + n * (4 + g), mid + n * (5 + g), tip + d * g,
				mid - n * (2 + g), hand + d * 14 - n * (4 + g)])
			_fill(ci, blade, col)
			ci.draw_line(hand - d * 26, hand + d * 8, col, 9.0 + g * 2)
			ci.draw_circle(hand + d * 12, 9.0 + g, col)
			if solid:
				ci.draw_polyline(PackedVector2Array([hand + d * 16 + n * 3, mid + n * 4, tip]), Color(rim.lightened(0.5), 0.85), 2.0)
				for k in 3:
					ci.draw_line(hand - d * (4 + k * 8) - n * 4, hand - d * (8 + k * 8) + n * 4, Color(rim, 0.8), 2.0)
		"axe":
			var tip2 := hand + d * 130.0
			ci.draw_line(hand - d * 28, tip2, col, 8.0 + g * 2)
			var hd := tip2 - d * 30.0
			var sgn := float(facing)
			var head := PackedVector2Array([hd + n * sgn * (6 + g) - d * 30, hd + n * sgn * (62 + g) - d * 44,
				hd + n * sgn * (74 + g) + d * 6, hd + n * sgn * (58 + g) + d * 46, hd + n * sgn * (6 + g) + d * 26])
			_fill(ci, head, col)
			_fill(ci, PackedVector2Array([hd - n * sgn * 4, hd - n * sgn * (30 + g) - d * 6,
				hd - n * sgn * 4 + d * 16]), col)
			if solid:
				ci.draw_polyline(PackedVector2Array([head[1], head[2], head[3]]), Color(rim.lightened(0.2), 0.9), 3.0)
		_:
			FighterPainter._weapon(ci, hand, deg, facing, weapon, col, g, false)


static func _smear(ci: CanvasItem, trail: PackedVector2Array, rim: Color) -> void:
	# trail holds pairs: [tip0, base0, tip1, base1, ...]; draw a fading crescent ribbon
	var n := trail.size() / 2
	for i in range(1, n):
		var a := float(i) / n
		var quad := PackedVector2Array([trail[(i - 1) * 2], trail[i * 2], trail[i * 2 + 1], trail[(i - 1) * 2 + 1]])
		_fill(ci, quad, Color(rim.lightened(0.35), a * 0.3))
	if n >= 2:
		var edge := PackedVector2Array()
		for i in n:
			edge.append(trail[i * 2])
		ci.draw_polyline(edge, Color(1, 1, 1, 0.55), 2.5)
