class_name HitSpark
extends Node2D
## Short burst of lines where a hit lands.

var color := Color.WHITE
var big := false
var t := 0.0
var _angles: Array = []


func _ready() -> void:
	for i in (12 if big else 7):
		_angles.append(randf() * TAU)


func _process(delta: float) -> void:
	t += delta
	if t > 0.28:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := t / 0.28
	var r := (80.0 if big else 50.0) * (0.4 + k)
	var a := 1.0 - k
	draw_circle(Vector2.ZERO, r * 0.45 * (1.0 - k), Color(1, 1, 1, a))
	for ang in _angles:
		var d := Vector2(cos(ang), sin(ang))
		draw_line(d * r * 0.3, d * r, Color(color, a), 5.0 if big else 3.0)
