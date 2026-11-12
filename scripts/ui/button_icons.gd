class_name ButtonIcons
extends RefCounted
## Vector icons for the touch buttons and the battle briefing.

## Icon per power id (falls back to one per power type).
const BY_ID := {
	"arc_bolt": "bolt", "thunder_step": "dash", "black_flame_wave": "flame", "hellfire_burst": "burst",
	"clear_sight": "eye", "piercing_gale": "wind", "veil_of_mist": "cloud", "mirror_double": "twin",
	"stone_bulwark": "wall", "quake_fist": "quake", "gravity_well": "spiral", "rising_stones": "rocks",
	"purify": "sparkle", "ribbon_lash": "whip", "venom_lash": "whip", "withering_curse": "drop",
}
const BY_TYPE := {
	"projectile": "bolt", "dash": "dash", "burst": "burst", "buff": "sparkle", "summon": "twin",
	"wall": "wall", "pull": "spiral", "lash": "whip", "drain": "drop",
}


static func for_power(p: Dictionary) -> String:
	return BY_ID.get(p.get("id", ""), BY_TYPE.get(p.get("type", ""), "burst"))


static func draw(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color, w := 0.0) -> void:
	var lw := w if w > 0.0 else maxf(3.0, r * 0.11)
	var s := r * 0.55
	match kind:
		"attack_light":  # one clean slash
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, lw * 1.3)
			ci.draw_line(c + Vector2(s * 0.55, -s), c + Vector2(s, -s * 0.55), col, lw)
		"attack_heavy":  # two heavy slashes
			ci.draw_line(c + Vector2(-s, s * 0.6), c + Vector2(s * 0.6, -s), col, lw * 1.6)
			ci.draw_line(c + Vector2(-s * 0.6, s), c + Vector2(s, -s * 0.6), col, lw * 1.6)
		"block":  # shield
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.7), c + Vector2(0, -s), c + Vector2(s * 0.8, -s * 0.7),
				c + Vector2(s * 0.7, s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.7, s * 0.2), c + Vector2(-s * 0.8, -s * 0.7)]), col, lw)
		"jump":  # double chevron up
			for k in 2:
				var y := s * 0.4 - k * s * 0.7
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, y + s * 0.35), c + Vector2(0, y - s * 0.3), c + Vector2(s * 0.7, y + s * 0.35)]), col, lw)
		"bolt":  # lightning zigzag
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.3, -s), c + Vector2(-s * 0.35, s * 0.05), c + Vector2(s * 0.2, s * 0.05),
				c + Vector2(-s * 0.3, s)]), col, lw * 1.2)
		"dash":  # speed chevrons
			for k in 3:
				var x := -s * 0.7 + k * s * 0.55
				ci.draw_polyline(PackedVector2Array([c + Vector2(x, -s * 0.6), c + Vector2(x + s * 0.45, 0), c + Vector2(x, s * 0.6)]), col, lw)
		"flame":
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.6, s * 0.1), c + Vector2(s * 0.35, s * 0.8),
				c + Vector2(-s * 0.35, s * 0.8), c + Vector2(-s * 0.6, s * 0.1), c + Vector2(-s * 0.15, -s * 0.3), c + Vector2(0, -s)]), col, lw)
			ci.draw_line(c + Vector2(0, s * 0.75), c + Vector2(0, s * 0.15), col, lw)
		"burst":  # star burst
			for k in 8:
				var a := k * TAU / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.35, c + Vector2(cos(a), sin(a)) * s * (1.0 if k % 2 == 0 else 0.7), col, lw)
		"eye":
			var pts := PackedVector2Array()
			for k in 13:
				var u := k / 12.0
				pts.append(c + Vector2(lerpf(-s, s, u), -sin(u * PI) * s * 0.6))
			for k in range(12, -1, -1):
				var u2 := k / 12.0
				pts.append(c + Vector2(lerpf(-s, s, u2), sin(u2 * PI) * s * 0.6))
			ci.draw_polyline(pts, col, lw)
			ci.draw_circle(c, s * 0.28, col)
		"wind":
			for k in 3:
				var y2 := -s * 0.5 + k * s * 0.5
				ci.draw_line(c + Vector2(-s, y2), c + Vector2(s * 0.6, y2), col, lw)
				ci.draw_arc(c + Vector2(s * 0.6, y2 - s * 0.18), s * 0.18, -PI / 2, PI / 2, 8, col, lw)
		"cloud":
			for o in [Vector2(-s * 0.4, s * 0.1), Vector2(0, -s * 0.2), Vector2(s * 0.4, s * 0.1)]:
				ci.draw_arc(c + o, s * 0.4, 0, TAU, 16, col, lw)
		"twin":
			for o in [-s * 0.35, s * 0.35]:
				ci.draw_circle(c + Vector2(o, -s * 0.45), s * 0.22, col)
				ci.draw_line(c + Vector2(o, -s * 0.2), c + Vector2(o, s * 0.7), col, lw * 1.2)
		"wall":
			for row in 3:
				var y3 := -s * 0.75 + row * s * 0.55
				ci.draw_rect(Rect2(c + Vector2(-s * 0.8, y3), Vector2(s * 1.6, s * 0.45)), col, false, lw * 0.8)
				ci.draw_line(c + Vector2((-0.2 if row % 2 else 0.2) * s, y3), c + Vector2((-0.2 if row % 2 else 0.2) * s, y3 + s * 0.45), col, lw * 0.8)
		"quake":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s, s * 0.6), c + Vector2(-s * 0.4, s * 0.6), c + Vector2(-s * 0.2, -s * 0.2),
				c + Vector2(s * 0.1, s * 0.6), c + Vector2(s * 0.35, -s * 0.6), c + Vector2(s * 0.6, s * 0.6), c + Vector2(s, s * 0.6)]), col, lw)
		"spiral":
			var sp := PackedVector2Array()
			for k in 40:
				var a2 := k * 0.4
				sp.append(c + Vector2(cos(a2), sin(a2)) * s * (1.0 - k / 40.0))
			ci.draw_polyline(sp, col, lw)
		"rocks":
			for o in [Vector2(-s * 0.5, s * 0.3), Vector2(s * 0.4, s * 0.4), Vector2(0, -s * 0.45)]:
				ci.draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.3, 0), c + o + Vector2(-s * 0.1, -s * 0.3),
					c + o + Vector2(s * 0.25, -s * 0.15), c + o + Vector2(s * 0.2, s * 0.2), c + o + Vector2(-s * 0.3, 0)]), col, lw * 0.8)
		"sparkle":
			for k in 4:
				var a3 := k * PI / 2.0
				ci.draw_line(c, c + Vector2(cos(a3), sin(a3)) * s, col, lw * 1.2)
			for k in 4:
				var a4 := PI / 4.0 + k * PI / 2.0
				ci.draw_line(c, c + Vector2(cos(a4), sin(a4)) * s * 0.5, col, lw)
		"whip":
			var wp := PackedVector2Array()
			for k in 14:
				var u3 := k / 13.0
				wp.append(c + Vector2(lerpf(-s, s, u3), sin(u3 * TAU * 1.2) * s * 0.35 * (1.0 - u3 * 0.5) + s * 0.2 - u3 * s * 0.5))
			ci.draw_polyline(wp, col, lw)
		"drop":
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.55, s * 0.15), c + Vector2(s * 0.35, s * 0.7),
				c + Vector2(-s * 0.35, s * 0.7), c + Vector2(-s * 0.55, s * 0.15), c + Vector2(0, -s)]), col, lw)
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.35), c + Vector2(s * 0.2, s * 0.35), col, lw)
		"swap":
			ci.draw_arc(c, s * 0.7, PI * 0.1, PI * 0.9, 12, col, lw)
			ci.draw_arc(c, s * 0.7, PI * 1.1, PI * 1.9, 12, col, lw)
		_:
			ci.draw_circle(c, s * 0.4, col)
