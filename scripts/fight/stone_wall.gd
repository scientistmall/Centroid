class_name StoneWall
extends Node2D
## Darin's Stone Bulwark: a slab that rises from the ground and destroys
## enemy projectiles that touch it.

var side := 0
var color := Color("d9a066")
var life := 3.0
var t := 0.0
const W := 70.0
const H := 240.0


func rect() -> Rect2:
	var rise := clampf(t / 0.15, 0.0, 1.0)
	return Rect2(position.x - W / 2, position.y - H * rise, W, H * rise)


func _physics_process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	for p in get_tree().get_nodes_in_group("projectiles"):
		if p.owner_fighter and p.owner_fighter.side != side and p.rect().intersects(rect()):
			p._pop()
	queue_redraw()


func _draw() -> void:
	var rise := clampf(t / 0.15, 0.0, 1.0)
	var fade := clampf((life - t) / 0.3, 0.0, 1.0)
	var h := H * rise
	var base := Color("3a3128").lerp(Color.BLACK, 0.2)
	var col := Color(base, fade)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-W / 2 - 8, 0), Vector2(-W / 2, -h * 0.85), Vector2(-W / 4, -h), Vector2(W / 3, -h * 0.94),
		Vector2(W / 2, -h * 0.7), Vector2(W / 2 + 8, 0)]), col)
	draw_polyline(PackedVector2Array([
		Vector2(-W / 2 - 8, 0), Vector2(-W / 2, -h * 0.85), Vector2(-W / 4, -h), Vector2(W / 3, -h * 0.94),
		Vector2(W / 2, -h * 0.7), Vector2(W / 2 + 8, 0)]), Color(color, 0.8 * fade), 4.0)
	# cracks
	draw_line(Vector2(-10, -h * 0.2), Vector2(6, -h * 0.45), Color(0, 0, 0, 0.6 * fade), 3)
	draw_line(Vector2(6, -h * 0.45), Vector2(-4, -h * 0.7), Color(0, 0, 0, 0.6 * fade), 3)
