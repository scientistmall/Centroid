class_name Portrait
extends Control
## Placeholder silhouette bust for dialogue scenes: black figure with a
## coloured rim light and a hair shape per character.

var char_id: String = ""
var facing_left := false
var _color := Color.WHITE
var _hair := "short"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_character(id: String, face_left: bool) -> void:
	char_id = id
	facing_left = face_left
	var c := StoryParser.character(id)
	_color = Color(c.get("color", "#cccccc"))
	_hair = c.get("hair", "short")
	visible = id != "" and _hair != "none"
	queue_redraw()


func _draw() -> void:
	if char_id == "":
		return
	var w := size.x
	var h := size.y
	if facing_left:
		draw_set_transform(Vector2(w, 0), 0, Vector2(-1, 1))
	var cx := w * 0.5
	var head_c := Vector2(cx, h * 0.36)
	var hr := w * 0.15
	# Rim glow passes, then black body on top.
	for pass_i in 2:
		var grow := 7.0 if pass_i == 0 else 0.0
		var col := Color(_color.r, _color.g, _color.b, 0.9) if pass_i == 0 else Color("050508")
		# shoulders / torso
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - w * 0.42 - grow, h + 2), Vector2(cx - w * 0.36 - grow, h * 0.66 - grow),
			Vector2(cx - w * 0.1, h * 0.56 - grow), Vector2(cx + w * 0.1, h * 0.56 - grow),
			Vector2(cx + w * 0.36 + grow, h * 0.66 - grow), Vector2(cx + w * 0.42 + grow, h + 2)]), col)
		# neck
		draw_rect(Rect2(cx - hr * 0.45 - grow, head_c.y + hr * 0.5, hr * 0.9 + grow * 2, h * 0.14), col)
		# head (slightly toward facing direction)
		draw_circle(head_c + Vector2(hr * 0.12, 0), hr + grow, col)
		_draw_hair(head_c, hr, grow, col)
	# eye glint facing right
	draw_circle(head_c + Vector2(hr * 0.62, -hr * 0.08), hr * 0.07, Color(_color.r, _color.g, _color.b, 0.95))
	draw_set_transform(Vector2.ZERO)


func _draw_hair(c: Vector2, r: float, g: float, col: Color) -> void:
	match _hair:
		"spiky":
			var pts := PackedVector2Array()
			for i in 7:
				var a := PI + i * PI / 6.0
				var rr := r * (1.55 if i % 2 == 0 else 1.05) + g
				pts.append(c + Vector2(cos(a), sin(a)) * rr + Vector2(-r * 0.15, 0))
			pts.append(c + Vector2(r * 0.9, 0))
			pts.append(c + Vector2(-r * 0.9, r * 0.3))
			draw_colored_polygon(pts, col)
		"long":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 1.1 - g, -r * 0.4), c + Vector2(-r * 0.3, -r * 1.2 - g), c + Vector2(r * 0.9, -r * 0.9 - g),
				c + Vector2(r * 0.4, -r * 0.2), c + Vector2(-r * 0.6, r * 2.6 + g), c + Vector2(-r * 1.4 - g, r * 2.4)]), col)
		"tied":
			draw_circle(c + Vector2(-r * 1.15, -r * 0.5), r * 0.45 + g, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.4, -r * 0.4), c + Vector2(-r * 1.9 - g, r * 1.6), c + Vector2(-r * 1.0, r * 0.2)]), col)
		"mohawk":
			for i in 5:
				var a := PI * 1.15 + i * 0.32
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(cos(a - 0.12), sin(a - 0.12)) * r, c + Vector2(cos(a), sin(a)) * (r * 1.7 + g),
					c + Vector2(cos(a + 0.12), sin(a + 0.12)) * r]), col)
		"hood":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 1.5 - g, r * 1.8), c + Vector2(-r * 1.3 - g, -r * 0.9), c + Vector2(0, -r * 1.5 - g),
				c + Vector2(r * 1.2 + g, -r * 0.7), c + Vector2(r * 0.9, r * 0.1), c + Vector2(-r * 0.3, r * 1.9)]), col)
		"elder":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 1.15 - g, 0), c + Vector2(-r * 0.4, -r * 1.15 - g), c + Vector2(r * 0.8, -r * 0.95 - g),
				c + Vector2(r * 0.3, -r * 0.3), c + Vector2(-r * 0.5, r * 1.5 + g), c + Vector2(-r * 1.2 - g, r * 1.2)]), col)
			# beard
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.2, r * 0.5), c + Vector2(r * 1.0, r * 0.45), c + Vector2(r * 0.5, r * 1.5 + g)]), col)
		"swept":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 1.1 - g, r * 0.2), c + Vector2(-r * 0.9, -r * 1.0 - g), c + Vector2(r * 1.3 + g, -r * 1.1 - g),
				c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.6, r * 0.6)]), col)
		"messy":
			for i in 6:
				var a := PI * 1.05 + i * 0.28
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.95, r * 0.42 + g, col)
		"shaved":
			pass
		_:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 1.05 - g, r * 0.1), c + Vector2(-r * 0.6, -r * 1.1 - g), c + Vector2(r * 0.9, -r * 0.95 - g),
				c + Vector2(r * 0.6, -r * 0.45), c + Vector2(-r * 0.7, r * 0.3)]), col)
