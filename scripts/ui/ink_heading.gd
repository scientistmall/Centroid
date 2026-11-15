class_name InkHeading
extends Control
## A heading in comic lettering (Ink.shout): white letters, ink outline, a coloured outer
## stroke and a hard shadow, tilted a touch like a manga sound effect.

var text := ""
var font_size := 96
var color := Color.WHITE
var stroke := Ink.RED
var tilt := -0.035


static func make(txt: String, fs := 96, stroke_col := Ink.RED, col := Color.WHITE) -> InkHeading:
	var h := InkHeading.new()
	h.text = txt
	h.font_size = fs
	h.stroke = stroke_col
	h.color = col
	h.custom_minimum_size = Vector2(0, fs * 1.15)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _draw() -> void:
	Ink.shout(self, Vector2(size.x / 2.0, size.y * 0.5 + font_size * 0.36), text, font_size, color, stroke, true, tilt)
