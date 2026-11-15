class_name LoadingRing
extends Control
## The boot loader on the title screen: a thin gold ring that fills with real loading progress
## while the Centroid crystal orbits along it, trailing light. When loading is done the ring
## flashes, the crystal glides into the centre, and "TAP TO START" fades in.

signal start_pressed

var progress := 0.0          # 0..1, set by whoever is loading
var centre_frac := Vector2(0.5, 0.865)   # where the ring sits (the Centroid's place on the altar)
var done := false
var _shown := 0.0            # eased progress actually drawn
var _t := 0.0
var _angle := -PI / 2.0
var _settle := 0.0           # 0 = orbiting, 1 = resting in the centre
var _flash := 0.0
var _tap := 0.0              # "TAP TO START" fade-in
var _trail: Array[Vector2] = []

const TRAIL := 18


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func finish() -> void:
	if done:
		return
	done = true
	progress = 1.0
	_flash = 1.0


func _gui_input(e: InputEvent) -> void:
	var tapped: bool = (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed) or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed)
	if tapped and done and _tap > 0.5:
		accept_event()
		start_pressed.emit()


func _process(delta: float) -> void:
	_t += delta
	_shown = move_toward(_shown, progress, delta * 0.9)
	_shown = lerpf(_shown, progress, 1.0 - exp(-delta * 4.0))
	if done and _shown > 0.995:
		_settle = minf(1.0, _settle + delta * 1.4)
		if _settle >= 1.0:
			_tap = minf(1.0, _tap + delta * 1.6)
	_flash = maxf(0.0, _flash - delta * 1.5)
	# orbit speed eases off as the crystal settles
	_angle += delta * TAU * 0.55 * (1.0 - _settle)
	_trail.push_front(_crystal_pos())
	if _trail.size() > TRAIL:
		_trail.pop_back()
	queue_redraw()


func _radius() -> float:
	return size.y * 0.11


func _centre() -> Vector2:
	return Vector2(size.x * centre_frac.x, size.y * centre_frac.y)


func _crystal_pos() -> Vector2:
	var on_ring := _centre() + Vector2(cos(_angle), sin(_angle)) * _radius()
	var k := _settle * _settle * (3.0 - 2.0 * _settle)
	return on_ring.lerp(_centre(), k)


func _draw() -> void:
	var c := _centre()
	var r := _radius()
	var gold := Metal.GOLD
	var fade := 1.0 - _tap   # the ring hands over to the tap prompt
	# soft dark disc so the ring reads over any wallpaper
	for i in 6:
		draw_circle(c, r * (1.9 - i * 0.12), Color(0, 0, 0, 0.07 * fade))
	# track + filled arc (from the top, clockwise)
	draw_arc(c, r, 0.0, TAU, 96, Color(gold, 0.18 * fade), 3.0, true)
	if _shown > 0.001:
		var a0 := -PI / 2.0
		var a1 := a0 + TAU * _shown
		draw_arc(c, r, a0, a1, 96, Color(gold, 0.16 * fade), 14.0, true)
		draw_arc(c, r, a0, a1, 96, Color(gold.lightened(0.3), 0.95 * fade), 4.0, true)
	if _flash > 0.0:
		draw_arc(c, r, 0.0, TAU, 96, Color(1.0, 0.95, 0.8, _flash), 6.0 + 30.0 * (1.0 - _flash), true)
	# light trail behind the crystal
	for i in range(_trail.size() - 1, 0, -1):
		var k := 1.0 - float(i) / TRAIL
		draw_circle(_trail[i], r * 0.09 * k, Color(1.0, 0.85, 0.45, 0.35 * k * k * (1.0 - _settle)))
	var p := _crystal_pos()
	var s := size.y * 0.06 * (0.5 + 0.5 * _settle)
	draw_centroid(self, p, s, _t)
	# percentage inside the ring, the caption under it
	var f := UiStyle.bold_font()
	var fs := int(size.y * 0.024)
	var lf := 1.0 - _settle
	if lf > 0.01:
		var txt := "%d%%" % int(round(_shown * 100.0))
		draw_string(f, c + Vector2(-r, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 0.93, 0.75, 0.9 * lf))
		draw_string(f, c + Vector2(-r * 4.0, r + fs * 1.5), "AWAKENING THE CENTROID", HORIZONTAL_ALIGNMENT_CENTER, r * 8.0,
			int(fs * 0.75), Color(0.85, 0.82, 0.95, 0.7 * lf))
	if _tap > 0.0:
		var pulse := 0.7 + 0.3 * sin(_t * 3.2)
		var tfs := int(size.y * 0.042)
		Metal.shout(self, Vector2(size.x * 0.5, size.y * 0.93), "TAP TO START", tfs, Color(1, 1, 1, _tap * pulse), Metal.GOLD, true)


## The Centroid: a star-shaped faceted crystal with a warm inner glow (also used by the wallpaper).
static func draw_centroid(ci: CanvasItem, p: Vector2, s: float, t: float) -> void:
	var breathe := 1.0 + 0.06 * sin(t * 2.2)
	for i in 7:
		var k := float(i) / 6.0
		ci.draw_circle(p, s * (3.2 - k * 2.4) * breathe, Color(1.0, 0.82, 0.4, 0.035 + 0.05 * k))
	var spin := t * 0.6
	var pts := PackedVector2Array()
	var n := 8
	for i in n * 2:
		var a := spin + PI * i / n
		var rr := s * (1.0 if i % 2 == 0 else 0.42)
		if i % 4 == 0:
			rr *= 1.25
		pts.append(p + Vector2(cos(a), sin(a)) * rr * Vector2(1.0, 1.15))
	# facets: alternate light and shade wedges from the centre
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var lit := 0.55 + 0.45 * sin(float(i) * 1.7 + t * 1.3)
		var col := Color(1.0, 0.9, 0.6).lerp(Color(1.0, 0.98, 0.9), lit)
		if i % 2 == 1:
			col = col.darkened(0.25)
		ci.draw_colored_polygon(PackedVector2Array([p, a, b]), col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(1.0, 0.75, 0.3, 0.9), maxf(1.5, s * 0.06), true)
	ci.draw_circle(p, s * 0.22, Color(1, 1, 1, 0.95))
