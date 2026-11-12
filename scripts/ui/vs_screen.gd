class_name VsScreen
extends Control
## Pre-fight VS screen: two coloured halves slam in with each fighter, name and
## epithet; a metal VS emblem crashes into the centre; the day / place strip
## slides up. Tap or wait ~3.2 s to continue.

signal closed

var left_id := ""
var right_id := ""
var place := ""
var t := 0.0
var _done := false
var _halves: Array = []
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var half := _Half.new()
		half.vs = self
		half.right = i == 1
		half.char_id = left_id if i == 0 else right_id
		half.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		add_child(half)
		half.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := Portrait.new()
		half.add_child(p)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.set_character(half.char_id, i == 1)
		p.set_expression("angry" if i == 1 else "determined")
		half.portrait = p
		_halves.append(half)
	var top := _Overlay.new()
	top.vs = self
	_overlay = top
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioManager.sfx("cutin")


func _process(delta: float) -> void:
	t += delta
	if t > 0.5 and t - delta <= 0.5:
		AudioManager.sfx("gong", -6.0)
	if _overlay:
		_overlay.queue_redraw()
	for h in _halves:
		h.queue_redraw()
		h.layout_portrait()
	if t > 3.2:
		_close()


func _gui_input(event: InputEvent) -> void:
	if ((event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed) and t > 0.4:
		accept_event()
		_close()


func _close() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	queue_free()


func slide(delay := 0.0) -> float:
	return ease(clampf((t - delay) / 0.32, 0.0, 1.0), 0.35)


## One coloured half, cut along the diagonal; masks the portrait inside it.
class _Half extends Control:
	var vs: VsScreen
	var right := false
	var char_id := ""
	var portrait: Portrait

	func _poly() -> PackedVector2Array:
		var w := size.x
		var h := size.y
		var k := vs.slide(0.0)
		var off := (1.0 - k) * w * 0.6 * (1.0 if right else -1.0)
		if right:
			return PackedVector2Array([Vector2(w * 0.56 + off, 0), Vector2(w + off, 0), Vector2(w + off, h), Vector2(w * 0.44 + off, h)])
		return PackedVector2Array([Vector2(off, 0), Vector2(w * 0.56 + off, 0), Vector2(w * 0.44 + off, h), Vector2(off, h)])

	func layout_portrait() -> void:
		if portrait == null:
			return
		var w := size.x
		var h := size.y
		var k := vs.slide(0.08)
		var off := (1.0 - k) * w * 0.7 * (1.0 if right else -1.0)
		portrait.size = Vector2(h * 0.78, h * 0.95)
		portrait.position = Vector2((w * 0.86 - portrait.size.x if right else w * 0.14) + off, h * 0.0)

	func _draw() -> void:
		var col := Color(StoryParser.character(char_id).get("color", "#ffffff"))
		var poly := _poly()
		var cols := PackedColorArray()
		for v in poly:
			cols.append(col.darkened(0.55).lerp(Color("05060a"), clampf(v.y / maxf(1.0, size.y), 0.0, 1.0) * 0.8))
		draw_polygon(poly, cols)
		# speed streaks
		var rng := RandomNumberGenerator.new()
		rng.seed = 3 if right else 7
		for i in 18:
			var y := rng.randf() * size.y
			var x := rng.randf_range(0.0, size.x)
			draw_line(Vector2(x, y), Vector2(x + rng.randf_range(80, 260) * (-1.0 if right else 1.0), y), Color(col, 0.12), 3.0)


## Edges, names, VS emblem and the place strip, drawn above both halves.
class _Overlay extends Control:
	var vs: VsScreen

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var k := vs.slide(0.0)
		# bright seam along the diagonal
		draw_line(Vector2(w * 0.56, 0), Vector2(w * 0.44, h), Color(1, 1, 1, 0.8 * k), 6.0)
		draw_line(Vector2(w * 0.56, 0), Vector2(w * 0.44, h), Color(Metal.GOLD, 0.5 * k), 18.0)
		for i in 2:
			var id := vs.left_id if i == 0 else vs.right_id
			var info := StoryParser.character(id)
			var col := Color(info.get("color", "#ffffff"))
			var nk := vs.slide(0.25)
			var x := (w * 0.06 if i == 0 else w * 0.94) + (1.0 - nk) * 400.0 * (-1.0 if i == 0 else 1.0)
			var nm := String(info.get("name", id.to_upper()))
			var f := Metal.display_bold()
			var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 150).x
			var nx := x if i == 0 else x - nw
			draw_string_outline(f, Vector2(nx, h * 0.80), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, 18, Color(0, 0, 0, 0.9))
			draw_string(f, Vector2(nx, h * 0.80), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, Color.WHITE)
			var tt := String(info.get("title", "")).to_upper()
			var tf := Metal.display_font()
			var tw := tf.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
			draw_string_outline(tf, Vector2(x if i == 0 else x - tw, h * 0.86), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 10, Color(0, 0, 0, 0.9))
			draw_string(tf, Vector2(x if i == 0 else x - tw, h * 0.86), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, col.lightened(0.3))
		# VS emblem slams in
		var vk := clampf((vs.t - 0.45) / 0.16, 0.0, 1.0)
		if vk > 0.0:
			var sc := lerpf(3.0, 1.0, ease(vk, 0.3))
			var c := Vector2(w * 0.5, h * 0.45)
			draw_set_transform(c, 0.0, Vector2(sc, sc))
			Metal.panel(self, Rect2(-120, -95, 240, 190), Metal.GOLD, 34.0, Color("4a5468"), Color("0e1118"), 0.9, [true, true, true, true])
			Metal.shout(self, Vector2(0, 62), "VS", 170, Metal.GOLD, Metal.GOLD)
			draw_set_transform(Vector2.ZERO)
			if vk < 1.0:
				draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, (1.0 - vk) * 0.4))
		# place strip
		var pk := vs.slide(0.7)
		if pk > 0.0 and vs.place != "":
			var sy := h - 110 * pk
			Metal.panel(self, Rect2(w * 0.22, sy, w * 0.56, 84), Metal.CYAN, 18.0, Color("2a303c"), Color("0b0d12"), 0.5, [true, true, true, true])
			Metal.shout(self, Vector2(w / 2, sy + 70), vs.place.to_upper(), 58, Color.WHITE, Metal.CYAN)
