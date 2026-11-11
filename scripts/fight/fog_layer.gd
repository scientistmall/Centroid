class_name FogLayer
extends Node2D
## Drifting mist drawn over the fighters (Vaska's arena). `density` 0..1.

var density := 1.0
var strength := 1.0   # front layers use less so fighters stay readable
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if density <= 0.01:
		return
	var vis := get_viewport_rect().size
	for i in 9:
		var speed := 18.0 + i * 7.0
		var y := vis.y * (0.35 + 0.06 * i)
		var x := fmod(i * 431.0 + _t * speed * (1.0 if i % 2 == 0 else -1.0), vis.x + 900.0)
		if x < 0:
			x += vis.x + 900.0
		x -= 450.0
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 420.0, Color(0.72, 0.78, 0.86, 0.07 * density * strength))
		draw_circle(Vector2.ZERO, 260.0, Color(0.8, 0.84, 0.9, 0.06 * density * strength))
	draw_set_transform(Vector2.ZERO)
