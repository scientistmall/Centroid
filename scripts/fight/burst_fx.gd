class_name BurstFx
extends Node2D
## Expanding ring for area powers.

var radius := 250.0
var color := Color.WHITE
var dark_core := false
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t > 0.45:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if Vfx3D.on():
		return
	var k := t / 0.45
	var r := radius * (0.3 + 0.7 * k)
	var a := 1.0 - k
	if dark_core:
		draw_circle(Vector2.ZERO, r * 0.8, Color(0.02, 0, 0.02, 0.6 * a))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, a), 14.0)
	draw_arc(Vector2.ZERO, r * 0.8, 0, TAU, 48, Color(1, 1, 1, a * 0.6), 4.0)
