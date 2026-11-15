@tool
class_name StyleBoxInk
extends StyleBox
## Theme StyleBox for the manga look (see Ink): a slanted panel with a thick ink outline, a hard
## offset shadow, screentone shading and an optional accent stripe. Pressed buttons sink into
## their shadow.

@export var fill: Color = Ink.PAPER
@export var accent := Color(0, 0, 0, 0)
@export var frame := Color(0, 0, 0, 0)     # inner hairline (white on dark panels)
@export var slant := 14.0
@export var shadow := 7.0
@export var pressed := false
@export var tone := true
@export var outline := 5.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	var r := rect
	var sh := shadow
	if pressed:
		r.position += Vector2(shadow * 0.7, shadow * 0.7)
		sh = shadow * 0.3
	var pts := Ink.slanted(r, slant)
	if sh > 0.0:
		var sp := PackedVector2Array()
		for v in pts:
			sp.append(v + Vector2(sh, sh))
		rs.canvas_item_add_polygon(to_canvas_item, sp, PackedColorArray([Color(0, 0, 0, 0.85)]))
	rs.canvas_item_add_polygon(to_canvas_item, pts, PackedColorArray([fill]))
	if tone:
		var light := fill.get_luminance() > 0.5
		var dot := Color(Ink.INK, 0.2) if light else Color(1, 1, 1, 0.08)
		for d in Ink.tone_dots(pts, r, dot, 9.0, 2.3):
			rs.canvas_item_add_circle(to_canvas_item, d[0], d[1], dot)
	if accent.a > 0.0:
		var bar := Rect2(r.position, Vector2(minf(12.0, r.size.x * 0.05), r.size.y))
		rs.canvas_item_add_polygon(to_canvas_item, Ink.slanted(bar, slant), PackedColorArray([accent]))
	var ol := pts.duplicate()
	ol.append(pts[0])
	rs.canvas_item_add_polyline(to_canvas_item, ol, PackedColorArray([Ink.INK]), outline, true)
	if frame.a > 0.0:
		var inner := Ink.slanted(r.grow(-outline - 2.0), slant)
		inner.append(inner[0])
		rs.canvas_item_add_polyline(to_canvas_item, inner, PackedColorArray([frame]), 2.0, true)
