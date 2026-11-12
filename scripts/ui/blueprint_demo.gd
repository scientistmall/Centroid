class_name BlueprintDemo
extends Control
## A looping technical-drawing animation for the battle briefing.
##
## mode "move":    one fighter performs `action` (a move/power dict, or "block"/"jump")
##                 with blueprint annotations (reach lines, paths, radii).
## mode "counter": the enemy (right) performs `threat` (a power dict) and the player
##                 (left) answers with `answer` ("jump", "block", "back", "dash", "power_1"...).

const LOOP := 2.4
const INK := Color("cfe8ff")
const SCALE := 0.40

var mode := "move"
var actor: Dictionary = {}        # fighter data (left, or the only one)
var foe: Dictionary = {}          # fighter data (right)
var action = null                 # Dictionary or String
var threat: Dictionary = {}
var answer := ""
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	t = fmod(t + delta, LOOP)
	queue_redraw()


# ------------------------------------------------------------------ helpers

func _ground() -> float:
	return size.y - 18.0


func _pose_for(anim: String, tt: float, startup: float, active: float, recovery: float, airborne := false) -> Dictionary:
	var base := Poses.get_pose("air") if airborne else Poses.idle_breath(tt)
	if tt < 0.0:
		return base
	var w := Poses.get_pose(anim + "_w")
	var s := Poses.get_pose(anim + "_s")
	if tt < startup:
		return Poses.blend(base, w, tt / maxf(0.01, startup))
	if tt < startup + active:
		return Poses.blend(w, s, minf(1.0, (tt - startup) / maxf(0.01, active * 0.5)))
	return Poses.blend(s, base, (tt - startup - active) / maxf(0.01, recovery))


func _paint_fighter(data: Dictionary, pos: Vector2, facing: int, pose: Dictionary, dim := 1.0) -> void:
	var col := Color(data.get("color", "#ffffff")).lerp(INK, 0.2)
	col.a *= dim
	draw_set_transform(pos, 0.0, Vector2(SCALE, SCALE))
	var costume: Dictionary = PortraitArt.look_for(data.get("id", "")).get("fighter", {})
	if costume.is_empty():
		FighterPainter.paint(self, pose, facing, col, data.get("weapon", "sword"), "", t, 0.0, false)
	else:
		FighterArt.paint(self, pose, facing, col, data.get("weapon", "sword"), "", t, 0.0, false, costume, Vector2.ZERO, PackedVector2Array())
	draw_set_transform(Vector2.ZERO)


func _dash_line(a: Vector2, b: Vector2, col: Color, w := 2.0, dash := 12.0) -> void:
	var d := b - a
	var L := d.length()
	if L < 1.0:
		return
	var u := d / L
	var x := 0.0
	while x < L:
		draw_line(a + u * x, a + u * minf(x + dash, L), col, w)
		x += dash * 2.0


func _arrow(a: Vector2, b: Vector2, col: Color, w := 3.0) -> void:
	draw_line(a, b, col, w)
	var u := (b - a).normalized()
	var n := Vector2(-u.y, u.x)
	draw_colored_polygon(PackedVector2Array([b, b - u * 16 + n * 9, b - u * 16 - n * 9]), col)


## Engineering-style dimension line: |<---->|
func _dimension(x0: float, x1: float, y: float, col: Color) -> void:
	draw_line(Vector2(x0, y - 10), Vector2(x0, y + 10), col, 2.0)
	draw_line(Vector2(x1, y - 10), Vector2(x1, y + 10), col, 2.0)
	_arrow(Vector2((x0 + x1) / 2, y), Vector2(x1, y), col, 2.0)
	_arrow(Vector2((x0 + x1) / 2, y), Vector2(x0, y), col, 2.0)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.07, 0.15, 0.55))
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.25), false, 2.0)
	draw_line(Vector2(8, _ground()), Vector2(size.x - 8, _ground()), Color(INK, 0.35), 2.0)
	if mode == "counter":
		_draw_counter()
	else:
		_draw_move()


func _draw_move() -> void:
	var g := _ground()
	var x := size.x * 0.25
	var pos := Vector2(x, g)
	var tt := t - 0.4
	if action is String:
		match action:
			"block":
				_paint_fighter(actor, pos, 1, Poses.get_pose("block"))
				var ix := lerpf(size.x - 20, x + 60, clampf(t / 1.2, 0, 1))
				_arrow(Vector2(ix + 60, g - 60), Vector2(ix, g - 60), Color(1, 0.5, 0.4, 0.9))
				if t > 1.2:
					draw_arc(pos + Vector2(40, -60), 46, -PI / 2.5, PI / 2.5, 16, Color(INK, 1.0 - (t - 1.2)), 5.0)
			"jump":
				var k := clampf(tt / 1.1, 0.0, 1.0)
				var y := -sin(k * PI) * 90.0
				var p2 := pos + Vector2(k * 120.0, y)
				_paint_fighter(actor, p2, 1, Poses.get_pose("air") if k > 0.0 and k < 1.0 else Poses.idle_breath(t))
				var arc := PackedVector2Array()
				for i in 13:
					var u := i / 12.0
					arc.append(pos + Vector2(u * 120.0, -sin(u * PI) * 90.0 - 60))
				_dash_line(arc[0], arc[6], Color(INK, 0.5))
				_dash_line(arc[6], arc[12], Color(INK, 0.5))
		return
	var m: Dictionary = action
	var startup: float = m.get("startup", 0.1) * 1.6
	var active: float = m.get("active", 0.08) * 1.6
	var recovery: float = m.get("recovery", 0.2) * 1.6
	var type: String = m.get("type", "melee")
	var anim: String = m.get("anim", "cast" if m.has("type") else "slash")
	var fire := tt >= startup
	match type:
		"melee", "lash":
			_paint_fighter(actor, pos, 1, _pose_for(anim, tt, startup, active, recovery))
			var reach: float = float(m.get("reach", 150.0)) * SCALE
			_dimension(x, x + reach, g - 140.0 * SCALE * 2.2, Color(INK, 0.8))
			if fire and tt < startup + active + 0.3:
				var hr: Array = m.get("height", [-240, -60])
				draw_rect(Rect2(x + 4, g + float(hr[0]) * SCALE, reach, (float(hr[1]) - float(hr[0])) * SCALE), Color(1, 0.6, 0.4, 0.8), false, 3.0)
			if type == "lash" and fire:
				_arrow(Vector2(x + reach, g - 70), Vector2(x + reach * (0.4 if m.get("pull_in", false) else 1.1), g - 70), Color(1, 0.8, 0.5))
		"projectile":
			_paint_fighter(actor, pos, 1, _pose_for(anim, tt, startup, active, recovery))
			var y := g + float(m.get("y", -170)) * SCALE
			_dash_line(Vector2(x + 30, y), Vector2(size.x - 16, y), Color(INK, 0.45))
			if fire:
				var px := x + 30 + (tt - startup) * float(m.get("speed", 1200)) * SCALE * 0.6
				if px < size.x - 10:
					draw_circle(Vector2(px, y), 11, Color(actor.get("color", "#ffffff")))
					draw_circle(Vector2(px, y), 18, Color(Color(actor.get("color", "#ffffff")), 0.3))
		"dash":
			var k := clampf((tt - startup) / maxf(0.01, active * 1.5), 0.0, 1.0)
			var dx := k * size.x * 0.45
			_paint_fighter(actor, pos + Vector2(dx, 0), 1, _pose_for("dash", tt, startup, active, recovery))
			for i in 4:
				draw_line(pos + Vector2(dx - 30 - i * 26, -90), pos + Vector2(dx - 30 - i * 26, -20), Color(INK, 0.35 - i * 0.07), 4)
			_dash_line(Vector2(x, g - 50), Vector2(x + size.x * 0.45, g - 50), Color(INK, 0.4))
			_arrow(Vector2(x + size.x * 0.4, g - 50), Vector2(x + size.x * 0.48, g - 50), Color(INK, 0.8))
		"burst":
			_paint_fighter(actor, pos + Vector2(size.x * 0.2, 0), 1, _pose_for(anim, tt, startup, active, recovery))
			var c := pos + Vector2(size.x * 0.2, -50)
			var r: float = float(m.get("radius", 250.0)) * SCALE
			draw_arc(c, r, 0, TAU, 40, Color(INK, 0.4), 2.0)
			if fire:
				var rr := r * clampf((tt - startup) / 0.4, 0.0, 1.0)
				draw_arc(c, rr, 0, TAU, 40, Color(1, 0.55, 0.4, 0.9), 5.0)
		"buff", "summon", "wall", "pull", "drain":
			_paint_fighter(actor, pos, 1, _pose_for(anim, tt, startup, active, recovery))
			if fire:
				var c2 := pos + Vector2(0, -60)
				match type:
					"buff":
						draw_arc(c2, 70 + 6 * sin(t * 8.0), 0, TAU, 32, Color(Color(actor.get("color", "#ffffff")), 0.8), 4.0)
					"summon":
						_paint_fighter(actor, pos + Vector2(size.x * 0.35, 0), -1, Poses.idle_breath(t), 0.35)
					"wall":
						draw_rect(Rect2(pos.x + 50, g - 96, 26, 96), Color(INK, 0.8), false, 3.0)
						var px2 := lerpf(size.x - 20, pos.x + 80, clampf((tt - startup) / 0.6, 0, 1))
						draw_circle(Vector2(px2, g - 60), 9, Color(1, 0.5, 0.4))
					"pull":
						for i in 3:
							_arrow(Vector2(size.x - 30, g - 40 - i * 25), Vector2(size.x * 0.55, g - 40 - i * 25), Color(INK, 0.7))
					"drain":
						for i in 5:
							var u := fmod(t * 1.2 + i * 0.2, 1.0)
							draw_circle(Vector2(lerpf(size.x - 30, pos.x + 30, u), g - 70), 6, Color(0.6, 1.0, 0.5, 0.9))
		_:
			_paint_fighter(actor, pos, 1, _pose_for(anim, tt, startup, active, recovery))


func _draw_counter() -> void:
	## Enemy (right) uses `threat`; player (left) answers with `answer`.
	var g := _ground()
	var px := size.x * 0.22
	var ex := size.x * 0.80
	var ppos := Vector2(px, g)
	var epos := Vector2(ex, g)
	var startup: float = threat.get("startup", 0.2) * 1.6
	var tt := t - 0.3
	var etype: String = threat.get("type", "projectile")
	var fire := tt >= startup
	_paint_fighter(foe, epos, -1, _pose_for(threat.get("anim", "cast"), tt, startup, 0.1, 0.4))
	# where the threat is now (projectile x / burst radius)
	var proj_x := ex - 40.0
	if etype == "projectile" and fire:
		proj_x = ex - 40.0 - (tt - startup) * 520.0
		if proj_x > 10:
			var col := Color(foe.get("color", "#ff6644"))
			draw_circle(Vector2(proj_x, g - 30), 14, col)
			draw_circle(Vector2(proj_x, g - 30), 24, Color(col, 0.3))
			_arrow(Vector2(proj_x - 20, g - 30), Vector2(proj_x - 60, g - 30), Color(col, 0.7), 2.0)
	if etype == "burst" and fire:
		var r := float(threat.get("radius", 250.0)) * SCALE * clampf((tt - startup) / 0.4, 0.0, 1.0)
		draw_arc(epos + Vector2(0, -50), r, 0, TAU, 40, Color(1, 0.5, 0.35, 0.9), 5.0)
		draw_arc(epos + Vector2(0, -50), float(threat.get("radius", 250.0)) * SCALE, 0, TAU, 40, Color(INK, 0.3), 2.0)
	var ecol := Color(foe.get("color", "#ff6644"))
	if fire:
		match etype:
			"lash":
				var reach_x := ex - float(threat.get("reach", 400.0)) * SCALE * 1.4
				var wl := PackedVector2Array()
				for i in 14:
					var u := i / 13.0
					wl.append(Vector2(lerpf(ex - 40, reach_x, u), g - 70 + sin(u * TAU * 1.5 + t * 12.0) * 10.0))
				draw_polyline(wl, ecol, 4.0)
				if threat.has("apply_status"):
					for i in 4:
						var ph := fmod(t * 1.5 + i * 0.25, 1.0)
						draw_circle(Vector2(px + 10 - i * 8, g - 120 + ph * 80), 5, Color(0.45, 1.0, 0.35, 1.0 - ph))
			"drain":
				for i in 6:
					var u2 := fmod(t * 1.2 + i / 6.0, 1.0)
					draw_circle(Vector2(lerpf(px + 30, ex - 30, u2), g - 70), 6, Color(0.6, 1.0, 0.5, 0.9))
				draw_set_transform(ppos + Vector2(0, -60), 0.0, Vector2(1.0, 0.35))
				draw_arc(Vector2.ZERO, 50, 0, TAU, 20, Color(0.2, 0.5, 0.15, 0.9), 6.0)
				draw_set_transform(Vector2.ZERO)
			"pull":
				for i in 3:
					_arrow(Vector2(px + 40, g - 30 - i * 30), Vector2(px + 140, g - 30 - i * 30), Color(ecol, 0.8))
			"buff":
				draw_arc(epos + Vector2(0, -60), 70, 0, TAU, 32, Color(INK, 0.4), 3.0)
			"summon":
				_paint_fighter(foe, ppos + Vector2(-60, 0), 1, Poses.idle_breath(t), 0.35)
	# player's answer
	var ans_t := tt - startup - 0.15
	match answer:
		"jump":
			var k := clampf((tt - startup - 0.25) / 0.9, 0.0, 1.0)
			_paint_fighter(actor, ppos + Vector2(k * 40.0, -sin(k * PI) * minf(70.0, size.y * 0.3)), 1,
				Poses.get_pose("air") if k > 0.0 and k < 1.0 else Poses.idle_breath(t))
		"block":
			_paint_fighter(actor, ppos, 1, Poses.get_pose("block") if ans_t > -0.3 else Poses.idle_breath(t))
			if ans_t > 0.2:
				draw_arc(ppos + Vector2(40, -60), 46, -PI / 2.5, PI / 2.5, 16, Color(INK, 0.9), 5.0)
		"back":
			var k2 := clampf(ans_t / 0.5, 0.0, 1.0)
			_paint_fighter(actor, ppos + Vector2(-k2 * 70.0, 0), 1, Poses.walk_cycle(t, -1.0) if k2 > 0.0 and k2 < 1.0 else Poses.idle_breath(t))
			_arrow(ppos + Vector2(0, -150), ppos + Vector2(-70, -150), Color(INK, 0.8))
		"dash":
			var k3 := clampf((tt - startup - 0.3) / 0.35, 0.0, 1.0)
			var dx := k3 * (ex - px - 90.0)
			_paint_fighter(actor, ppos + Vector2(dx, 0), 1, Poses.get_pose("dash_s") if k3 > 0.0 and k3 < 1.0 else Poses.idle_breath(t))
			for i in 3:
				if k3 > 0.0 and k3 < 1.0:
					draw_line(ppos + Vector2(dx - 30 - i * 24, -90), ppos + Vector2(dx - 30 - i * 24, -20), Color(INK, 0.4 - i * 0.1), 4)
		_:
			_paint_fighter(actor, ppos, 1, _pose_for("cast", ans_t, 0.15, 0.1, 0.4))
			if ans_t > 0.15:
				draw_arc(ppos + Vector2(0, -60), 70, 0, TAU, 32, Color(Color(actor.get("color", "#ffffff")), 0.8), 4.0)
