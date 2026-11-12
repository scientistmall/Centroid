class_name LashFx
extends Node2D
## A whip / chain line that snaps from `from` to `to` and fades (Venom Lash,
## Ribbon Lash, Withering Curse).

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color.WHITE
var t := 0.0
const LIFE := 0.22


func _process(delta: float) -> void:
	t += delta
	if t > LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / (LIFE * 0.4), 0.0, 1.0)      # extends quickly
	var fade := 1.0 - clampf((t - LIFE * 0.4) / (LIFE * 0.6), 0.0, 1.0)
	var end := from.lerp(to, k)
	var d := end - from
	var n := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	for i in 16:
		var u := i / 15.0
		var wave := sin(u * TAU * 1.5 + t * 40.0) * 18.0 * (1.0 - u) * (1.0 - k * 0.6)
		pts.append(from + d * u + n * wave)
	draw_polyline(pts, Color(color, 0.35 * fade), 12.0)
	draw_polyline(pts, Color(color.lightened(0.4), 0.95 * fade), 4.0)
	draw_circle(end, 9.0, Color(1, 1, 1, 0.8 * fade))
