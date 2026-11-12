@tool
class_name StyleBoxMetal
extends StyleBox
## Theme StyleBox drawing the heavy-metal look (chamfered gunmetal or gold panel
## with bevel and glowing trim) via RenderingServer, so any Button/Panel can use it.

@export var trim := Color("6fe3ff")
@export var top := Color("3b4352")
@export var bottom := Color("10131a")
@export var cut := 16.0
@export var glow := 0.5
@export var pressed_offset := 0.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var r := rect
	if pressed_offset != 0.0:
		r.position.y += pressed_offset
	var rs := RenderingServer
	var cuts := [true, false, true, false]
	if glow > 0.0:
		for i in 3:
			var g := Metal.chamfer(r.grow(3.0 + i * 3.0), cut + i * 2.0, cuts)
			g.append(g[0])
			rs.canvas_item_add_polyline(to_canvas_item, g, PackedColorArray([Color(trim, glow * (0.22 - i * 0.06))]), 3.0)
	var pts := Metal.chamfer(r, cut, cuts)
	var cols := PackedColorArray()
	for v in pts:
		cols.append(top.lerp(bottom, clampf((v.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	rs.canvas_item_add_polygon(to_canvas_item, pts, cols)
	rs.canvas_item_add_line(to_canvas_item, Vector2(r.position.x + cut, r.position.y + 2), Vector2(r.end.x - 4, r.position.y + 2), Color(1, 1, 1, 0.3), 2.0)
	rs.canvas_item_add_line(to_canvas_item, Vector2(r.position.x + 4, r.end.y - 2), Vector2(r.end.x - cut, r.end.y - 2), Color(0, 0, 0, 0.5), 3.0)
	var outline := pts.duplicate()
	outline.append(outline[0])
	rs.canvas_item_add_polyline(to_canvas_item, outline, PackedColorArray([trim]), 3.0)
