class_name Projectile
extends Node2D
## A travelling power (lightning bolt, flame wave, orb...). Hits the target once.

var owner_fighter: Fighter
var target: Fighter
var params: Dictionary = {}
var color := Color.WHITE
var dir := 1
var speed := 1400.0
var life := 0.0
var max_life := 1.6
var fx := "orb"
var size := Vector2(90, 60)


func setup(from: Fighter, to: Fighter, p: Dictionary, col: Color) -> void:
	owner_fighter = from
	target = to
	params = p
	color = col
	dir = from.facing
	speed = p.get("speed", 1400.0)
	fx = p.get("fx", "orb")
	max_life = p.get("life", 1.6)
	if fx == "flame_wave":
		size = Vector2(110, 150)
	add_to_group("projectiles")


func rect() -> Rect2:
	return Rect2(position - Vector2(size.x / 2, size.y / 2), size)


func _physics_process(delta: float) -> void:
	life += delta
	position.x += dir * speed * delta
	queue_redraw()
	if life > max_life or position.x < -200 or position.x > 2200:
		queue_free()
		return
	# projectiles from opposite owners cancel each other
	for other in get_tree().get_nodes_in_group("projectiles"):
		if other != self and other.owner_fighter != owner_fighter and other.rect().intersects(rect()):
			_pop()
			other._pop()
			return
	for c in get_tree().get_nodes_in_group("clones"):
		if c.side != owner_fighter.side and rect().intersects(c.hurtbox()):
			c.pop()
	if target and target.is_alive() and rect().intersects(target.hurtbox()):
		var res := target.receive_hit(owner_fighter, params)
		if res != "miss":
			var s := HitSpark.new()
			s.position = position
			s.color = color if res == "hit" else Color(0.8, 0.85, 1.0)
			s.big = true
			get_parent().add_child(s)
			queue_free()


func _pop() -> void:
	var s := HitSpark.new()
	s.position = position
	s.color = color
	get_parent().add_child(s)
	queue_free()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(life * 40.0)
	match fx:
		"bolt":
			for i in 4:
				draw_circle(Vector2.ZERO, 40.0 - i * 8.0, Color(color.r, color.g, color.b, 0.12 + i * 0.08))
			for k in 3:
				var pts := PackedVector2Array()
				for i in 8:
					pts.append(Vector2(-dir * (i * 22.0 - 30.0), rng.randf_range(-22, 22)))
				draw_polyline(pts, Color(0.9, 0.98, 1.0, 0.95) if k == 0 else Color(color, 0.8), 3.0 if k == 0 else 2.0)
		"flame_wave":
			for i in 9:
				var x := rng.randf_range(-50, 50)
				var h := rng.randf_range(70, 160)
				var c := Color(0.04, 0.0, 0.02, 0.92) if i % 2 == 0 else Color(color, 0.85)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 24, size.y / 2), Vector2(x + dir * 18, size.y / 2 - h), Vector2(x + 24, size.y / 2)]), c)
		"wind":
			# a long translucent lance of wind with trailing streaks
			draw_colored_polygon(PackedVector2Array([
				Vector2(dir * 70, 0), Vector2(-dir * 60, -14), Vector2(-dir * 140, 0), Vector2(-dir * 60, 14)]),
				Color(0.9, 1.0, 0.95, 0.75))
			for k in 4:
				var y := rng.randf_range(-26, 26)
				draw_line(Vector2(-dir * 40, y), Vector2(-dir * rng.randf_range(140, 230), y), Color(color, 0.55), 2.0)
		_:
			for i in 4:
				draw_circle(Vector2.ZERO, 34.0 - i * 7.0, Color(color.r, color.g, color.b, 0.2 + i * 0.2))
