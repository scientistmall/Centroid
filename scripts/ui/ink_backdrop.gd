class_name InkBackdrop
extends Control
## Behind every pop-up (settings, pause, dialogs): the screen goes dark under radiating manga
## speed lines that drift slowly, the way a manga page frames a dramatic beat. Blocks input.

var t := 0.0
var _a := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	t += delta
	_a = minf(1.0, _a + delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.78 * _a))
	var r1 := size.length()
	draw_set_transform(c, t * 0.02, Vector2.ONE)
	Ink.speed_lines(self, Vector2.ZERO, size.y * 0.42, r1, 90, Color(1, 1, 1, 0.05 * _a), 11)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
