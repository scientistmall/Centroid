class_name CutIn
extends Control
## Anime-style "power cut-in": a diagonal band sweeps across the screen with the
## fighter's face and the power's name (~0.9 s). The band masks the face
## (clip_children), so the face never spills outside it.

var char_id := ""
var accent := Color.WHITE
var power_name := ""
var from_left := true
var t := 0.0
const DURATION := 0.9

var look: Dictionary = {}
var _mask: BandMask
var _face: Face
var _text: TextLayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	look = PortraitArt.look_for(char_id).get("portrait", {})
	_mask = BandMask.new()
	_mask.cut = self
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_mask)
	_face = Face.new()
	_face.cut = self
	_mask.add_child(_face)
	_text = TextLayer.new()
	_text.cut = self
	add_child(_text)
	for c in [_mask, _face, _text]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	if t >= DURATION:
		queue_free()
		return
	queue_redraw()
	_mask.queue_redraw()
	_face.queue_redraw()
	_text.queue_redraw()


## 0 = off-screen, 1 = centred: fast in, hold, fast out.
func slide() -> float:
	if t < 0.16:
		return ease(t / 0.16, 0.4)
	if t > DURATION - 0.16:
		return ease((DURATION - t) / 0.16, 0.4)
	return 1.0


func shift() -> float:
	return (1.0 - slide()) * size.x * 1.1 * (-1.0 if from_left else 1.0)


func band() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var bh := h * 0.30
	var cy := h * 0.42
	var skew := h * 0.12
	var s := shift()
	return PackedVector2Array([
		Vector2(-50 + s, cy - bh / 2 + skew), Vector2(w + 50 + s, cy - bh / 2 - skew),
		Vector2(w + 50 + s, cy + bh / 2 - skew), Vector2(-50 + s, cy + bh / 2 + skew)])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35 * slide()))


class BandMask extends Control:
	var cut: CutIn

	func _draw() -> void:
		var b := cut.band()
		draw_colored_polygon(b, Color(0.03, 0.03, 0.06, 0.95))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(cut.t * 30.0)
		var dir := 1.0 if cut.from_left else -1.0
		var cy := size.y * 0.42
		for i in 16:
			var y := cy + rng.randf_range(-size.y * 0.2, size.y * 0.2)
			var x0 := rng.randf_range(0, size.x) + cut.shift()
			draw_line(Vector2(x0, y), Vector2(x0 + dir * rng.randf_range(120, 380), y), Color(cut.accent, 0.22), 2.0)


class Face extends Control:
	var cut: CutIn

	func _draw() -> void:
		if cut.look.is_empty():
			return
		var h := size.y
		var bh := h * 0.30
		var cy := h * 0.42
		var face_size := Vector2(bh * 2.6, bh * 3.4)
		var fx := (size.x * 0.22 if cut.from_left else size.x * 0.78) + cut.shift()
		var origin := Vector2(fx - face_size.x / 2, cy - face_size.y * 0.37)
		if cut.from_left:
			draw_set_transform(origin)
		else:
			draw_set_transform(origin + Vector2(face_size.x, 0), 0.0, Vector2(-1, 1))
		PortraitArt.paint(self, face_size, cut.look, "angry", 0.4, cut.accent)
		draw_set_transform(Vector2.ZERO)


class TextLayer extends Control:
	var cut: CutIn

	func _draw() -> void:
		var b := cut.band()
		draw_line(b[0], b[1], cut.accent, 6.0)
		draw_line(b[3], b[2], cut.accent, 6.0)
		var font := get_theme_default_font()
		var h := size.y
		var fs := int(h * 0.075)
		var txt := cut.power_name.to_upper()
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := (size.x * 0.42 if cut.from_left else size.x * 0.58 - tw) + cut.shift()
		var ty := h * 0.42 + fs * 0.35
		draw_string_outline(font, Vector2(tx, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(tx, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cut.accent.lightened(0.35))
