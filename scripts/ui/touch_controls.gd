class_name TouchControls
extends Control
## On-screen controls: floating joystick on the left half, action buttons on the right.
## Feeds the same input actions as the keyboard (Input.action_press/release).

const DEAD := 0.25
const JOY_R := 120.0

var buttons: Array = []   # {action, label, pos(relative to bottom-right), r, color}
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _btn_touch := {}      # touch index -> action
var _jump_held := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons = [
		{"action": "attack_light", "label": "ATK", "off": Vector2(-200, -190), "r": 92.0, "color": Color(0.9, 0.9, 1.0)},
		{"action": "attack_heavy", "label": "HVY", "off": Vector2(-390, -130), "r": 72.0, "color": Color(1.0, 0.7, 0.4)},
		{"action": "jump", "label": "JMP", "off": Vector2(-140, -390), "r": 66.0, "color": Color(0.6, 1.0, 0.7)},
		{"action": "block", "label": "BLK", "off": Vector2(-340, -320), "r": 66.0, "color": Color(0.6, 0.8, 1.0)},
		{"action": "power_1", "label": "P1", "off": Vector2(-560, -110), "r": 62.0, "color": Color(0.7, 0.9, 1.0)},
		{"action": "power_2", "label": "P2", "off": Vector2(-540, -280), "r": 62.0, "color": Color(0.9, 0.7, 1.0)},
	]


func set_power_labels(p1: String, p2: String, col: Color) -> void:
	for b in buttons:
		if b["action"] == "power_1":
			b["label"] = p1
			b["color"] = col.lightened(0.3)
		elif b["action"] == "power_2":
			b["label"] = p2
			b["color"] = col.lightened(0.1)
	queue_redraw()


func _btn_center(b: Dictionary) -> Vector2:
	return size + b["off"]


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var hit := _button_at(event.position)
			if hit != "":
				_btn_touch[event.index] = hit
				Input.action_press(hit)
			elif event.position.x < size.x * 0.45 and event.position.y > size.y * 0.2 and _joy_index == -1:
				_joy_index = event.index
				_joy_origin = event.position
				_joy_vec = Vector2.ZERO
		else:
			if _btn_touch.has(event.index):
				Input.action_release(_btn_touch[event.index])
				_btn_touch.erase(event.index)
			if event.index == _joy_index:
				_joy_index = -1
				_joy_vec = Vector2.ZERO
				_apply_joy()
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _joy_index:
		_joy_vec = ((event.position - _joy_origin) / JOY_R).limit_length(1.0)
		_apply_joy()
		queue_redraw()


func _button_at(p: Vector2) -> String:
	for b in buttons:
		if p.distance_to(_btn_center(b)) <= b["r"] * 1.15:
			return b["action"]
	return ""


func _apply_joy() -> void:
	var x := _joy_vec.x
	if x < -DEAD:
		Input.action_press("move_left", minf(1.0, -x * 1.3))
		Input.action_release("move_right")
	elif x > DEAD:
		Input.action_press("move_right", minf(1.0, x * 1.3))
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")
	var want_jump := _joy_vec.y < -0.6
	if want_jump and not _jump_held:
		Input.action_press("jump")
	elif not want_jump and _jump_held:
		Input.action_release("jump")
	_jump_held = want_jump


func release_all() -> void:
	for a in ["move_left", "move_right", "jump", "attack_light", "attack_heavy", "block", "power_1", "power_2"]:
		Input.action_release(a)
	_btn_touch.clear()
	_joy_index = -1
	_joy_vec = Vector2.ZERO


func _draw() -> void:
	var font := get_theme_default_font()
	# joystick
	var base := _joy_origin if _joy_index != -1 else Vector2(260, size.y - 230)
	draw_circle(base, JOY_R, Color(1, 1, 1, 0.08))
	draw_arc(base, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.3), 4)
	draw_circle(base + _joy_vec * JOY_R, 52, Color(1, 1, 1, 0.3))
	for b in buttons:
		var c := _btn_center(b)
		var pressed := _btn_touch.values().has(b["action"]) or Input.is_action_pressed(b["action"])
		var col: Color = b["color"]
		draw_circle(c, b["r"], Color(col, 0.35 if pressed else 0.14))
		draw_arc(c, b["r"], 0, TAU, 40, Color(col, 0.7), 4)
		var fs := 34 if String(b["label"]).length() <= 3 else 22
		var tw := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-tw / 2, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
