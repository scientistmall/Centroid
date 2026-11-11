class_name FighterPainter
extends RefCounted
## Draws a silhouette fighter from a pose dictionary (see Poses).
## Origin = point between the feet on the ground. Black body with a rim of
## the character's colour, plus a weapon and an element effect.

const TORSO := 112.0
const NECK := 16.0
const HEAD_R := 25.0
const UPPER_ARM := 56.0
const FOREARM := 52.0
const THIGH := 68.0
const SHIN := 66.0
const LIMB_W := 17.0

const BODY_COL := Color("06060a")
const BACK_COL := Color("17171f")


static func _dir(deg: float, facing: int) -> Vector2:
	var r := deg_to_rad(deg)
	return Vector2(sin(r) * facing, cos(r))


static func joints(p: Dictionary, facing: int) -> Dictionary:
	# Legs first, relative to the hip at (0,0); then lift so the lower foot touches y=0.
	var knee_f := _dir(p["th_f"], facing) * THIGH
	var foot_f := knee_f + _dir(p["th_f"] + p["sh_f"], facing) * SHIN
	var knee_b := _dir(p["th_b"], facing) * THIGH
	var foot_b := knee_b + _dir(p["th_b"] + p["sh_b"], facing) * SHIN
	var lift := maxf(foot_f.y, foot_b.y)
	var hip := Vector2(0, -lift)
	var lean := deg_to_rad(p["lean"])
	var up := Vector2(sin(lean) * facing, -cos(lean))
	var shoulder := hip + up * TORSO
	var head := shoulder + up * (NECK + HEAD_R)
	var elbow_f := shoulder + _dir(p["ua_f"], facing) * UPPER_ARM
	var hand_f := elbow_f + _dir(p["ua_f"] + p["la_f"], facing) * FOREARM
	var elbow_b := shoulder + _dir(p["ua_b"], facing) * UPPER_ARM
	var hand_b := elbow_b + _dir(p["ua_b"] + p["la_b"], facing) * FOREARM
	return {
		"hip": hip, "shoulder": shoulder, "head": head, "up": up,
		"knee_f": hip + knee_f, "foot_f": hip + foot_f, "knee_b": hip + knee_b, "foot_b": hip + foot_b,
		"elbow_f": elbow_f, "hand_f": hand_f, "elbow_b": elbow_b, "hand_b": hand_b,
	}


static func paint(ci: CanvasItem, p: Dictionary, facing: int, rim: Color, weapon: String,
		element: String, clock: float, flash: float = 0.0, charged: bool = false) -> void:
	var j := joints(p, facing)
	var rot := deg_to_rad(p.get("rot", 0.0)) * facing
	if rot != 0.0:
		ci.draw_set_transform(Vector2(0, -20), rot, Vector2.ONE)
	var body := BODY_COL.lerp(Color.WHITE, flash)
	var back := BACK_COL.lerp(Color.WHITE, flash)
	var glow := Color(rim.r, rim.g, rim.b, 0.85 if charged else 0.6)

	# Rim-light pass (slightly thicker, coloured), then the solid pass.
	for pass_i in 2:
		var extra := 6.0 if pass_i == 0 else 0.0
		var cb := glow if pass_i == 0 else back
		var cf := glow if pass_i == 0 else body
		_limb(ci, j["shoulder"], j["elbow_b"], j["hand_b"], LIMB_W - 2 + extra, cb)
		_limb(ci, j["hip"], j["knee_b"], j["foot_b"], LIMB_W + 1 + extra, cb)
		if weapon in ["twin_swords", "daggers"]:
			_weapon(ci, j["hand_b"], p.get("wpn_b", 120.0), facing, weapon, cb if pass_i == 1 else glow, extra, true)
		# torso as a tapered quad
		var side := Vector2(-j["up"].y, j["up"].x)
		var hip: Vector2 = j["hip"]
		var sh: Vector2 = j["shoulder"]
		ci.draw_colored_polygon(PackedVector2Array([
			hip - side * (15 + extra), hip + side * (15 + extra),
			sh + side * (24 + extra) - j["up"] * 4, sh - side * (24 + extra) - j["up"] * 4]), cf)
		ci.draw_circle(j["head"], HEAD_R + extra, cf)
		ci.draw_line(sh, j["head"], cf, 14 + extra)
		_limb(ci, j["hip"], j["knee_f"], j["foot_f"], LIMB_W + 2 + extra, cf)
		_limb(ci, j["shoulder"], j["elbow_f"], j["hand_f"], LIMB_W + extra, cf)
		if weapon != "none":
			_weapon(ci, j["hand_f"], p["wpn"], facing, weapon, cf if pass_i == 1 else glow, extra, false)

	# Eye glint
	ci.draw_circle(j["head"] + Vector2(10 * facing, -3), 3.0, rim)
	if element != "" and charged:
		_element_fx(ci, j, p, facing, rim, element, clock, weapon)
	ci.draw_set_transform(Vector2.ZERO)


static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, col, w)
	ci.draw_line(b, c, col, w * 0.9)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)
	ci.draw_circle(c, w * 0.45, col)


static func weapon_tip(p: Dictionary, facing: int, weapon: String) -> Vector2:
	var j := joints(p, facing)
	return j["hand_f"] + _dir(p["wpn"], facing) * weapon_length(weapon)


static func weapon_length(weapon: String) -> float:
	match weapon:
		"sword": return 135.0
		"axe": return 125.0
		"spear": return 190.0
		"twin_swords": return 115.0
		"daggers": return 60.0
		"bow": return 80.0
		"whip": return 150.0
		"gauntlets": return 10.0
		"flex_blade": return 140.0
		"crystal_blades": return 110.0
	return 120.0


static func _weapon(ci: CanvasItem, hand: Vector2, deg: float, facing: int, weapon: String, col: Color, extra: float, back_hand: bool) -> void:
	var d := _dir(deg, facing)
	var len := weapon_length(weapon)
	var tip := hand + d * len
	match weapon:
		"axe":
			ci.draw_line(hand - d * 20, tip, col, 7 + extra)
			var n := Vector2(-d.y, d.x) * facing
			ci.draw_colored_polygon(PackedVector2Array([
				tip - d * 10 + n * (4 + extra), tip - d * 48 + n * (6 + extra), tip - d * 70 + n * (50 + extra),
				tip - d * 5 + n * (55 + extra), tip + d * (6 + extra)]), col)
		"spear":
			ci.draw_line(hand - d * 70, tip, col, 6 + extra)
			var n2 := Vector2(-d.y, d.x)
			ci.draw_colored_polygon(PackedVector2Array([tip + d * (34 + extra), tip + n2 * (9 + extra), tip - n2 * (9 + extra)]), col)
		"gauntlets":
			ci.draw_circle(hand, 15 + extra, col)
		"bow":
			var n3 := Vector2(-d.y, d.x)
			var pts := PackedVector2Array()
			for i in 9:
				var t := -1.0 + i * 0.25
				pts.append(hand + n3 * t * 75 + d * (1.0 - t * t) * 28)
			ci.draw_polyline(pts, col, 5 + extra)
		_:
			# sword-like blades with a small guard
			var n4 := Vector2(-d.y, d.x)
			ci.draw_line(hand - n4 * (14 + extra), hand + n4 * (14 + extra), col, 6 + extra)
			ci.draw_line(hand, tip, col, (6 if len > 80 else 5) + extra)
			ci.draw_colored_polygon(PackedVector2Array([tip + d * (16 + extra), tip + n4 * (4 + extra), tip - n4 * (4 + extra)]), col)


static func _element_fx(ci: CanvasItem, j: Dictionary, p: Dictionary, facing: int, rim: Color, element: String, clock: float, weapon: String) -> void:
	var hand: Vector2 = j["hand_f"]
	var tip := hand + _dir(p["wpn"], facing) * weapon_length(weapon)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(clock * 30.0)
	match element:
		"lightning":
			for k in 2:
				var pts := PackedVector2Array()
				for i in 7:
					var t := i / 6.0
					pts.append(hand.lerp(tip, t) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)))
				ci.draw_polyline(pts, Color(0.85, 0.97, 1.0, 0.95), 2.5)
			ci.draw_circle(tip, 10, Color(rim.r, rim.g, rim.b, 0.35))
		"black_flame":
			var base := tip.lerp(hand, 0.25)
			for i in 6:
				var o := Vector2(rng.randf_range(-30, 30), rng.randf_range(-10, 20))
				var h := rng.randf_range(30, 70)
				ci.draw_colored_polygon(PackedVector2Array([
					base + o + Vector2(-12, 0), base + o + Vector2(0, -h), base + o + Vector2(12, 0)]),
					Color(0.05, 0.0, 0.02, 0.9) if i % 2 == 0 else Color(rim.r, rim.g, rim.b, 0.7))
		"wind":
			# streaks curling along the weapon
			for k in 3:
				var pts := PackedVector2Array()
				var off := rng.randf_range(-18, 18)
				for i in 8:
					var t := i / 7.0
					var n := Vector2(0, sin(t * PI * 2.0 + clock * 10.0 + k) * 14.0 + off)
					pts.append(hand.lerp(tip, t) + n)
				ci.draw_polyline(pts, Color(0.85, 1.0, 0.92, 0.55), 2.0)
		"mist":
			var c: Vector2 = j["shoulder"]
			for i in 7:
				var o := Vector2(rng.randf_range(-70, 70), rng.randf_range(-60, 160))
				ci.draw_circle(c + o, rng.randf_range(18, 34), Color(0.8, 0.85, 0.95, 0.12))
		_:
			ci.draw_circle(tip, 14, Color(rim.r, rim.g, rim.b, 0.4))
