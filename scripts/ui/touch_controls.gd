class_name TouchControls
extends Control
## On-screen controls: a floating joystick and icon buttons. Power buttons show an
## energy ring that fills up and glows when the power is ready. Size, opacity and
## left-handed layout come from Settings.
## Feeds the same input actions as the keyboard (Input.action_press/release).

const DEAD := 0.25
const JOY_R := 120.0

var buttons: Array = []   # {action, icon, off (from the bottom corner), r, color, power}
var fighter: Fighter      # for energy rings
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _btn_touch := {}      # touch index -> action
var _jump_held := false
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons = [
		{"action": "attack_light", "icon": "attack_light", "off": Vector2(-200, -190), "r": 92.0, "color": Color(0.9, 0.92, 1.0)},
		{"action": "attack_heavy", "icon": "attack_heavy", "off": Vector2(-390, -130), "r": 72.0, "color": Color(1.0, 0.72, 0.42)},
		{"action": "jump", "icon": "jump", "off": Vector2(-140, -390), "r": 66.0, "color": Color(0.6, 1.0, 0.72)},
		{"action": "block", "icon": "block", "off": Vector2(-340, -320), "r": 66.0, "color": Color(0.62, 0.8, 1.0)},
		{"action": "power_1", "icon": "bolt", "off": Vector2(-560, -110), "r": 64.0, "color": Color(0.7, 0.9, 1.0), "power": 0},
		{"action": "power_2", "icon": "dash", "off": Vector2(-540, -285), "r": 64.0, "color": Color(0.9, 0.7, 1.0), "power": 1},
	]


func set_fighter(f: Fighter) -> void:
	fighter = f
	for b in buttons:
		if b.has("power") and b["power"] < f.powers.size():
			b["icon"] = ButtonIcons.for_power(f.powers[b["power"]])
			b["color"] = f.color.lightened(0.25 if b["power"] == 0 else 0.05)
	queue_redraw()


func _scale() -> float:
	return Settings.button_scale


func _btn_center(b: Dictionary) -> Vector2:
	var off: Vector2 = b["off"] * _scale()
	if Settings.left_handed:
		return Vector2(-off.x, size.y + off.y)
	return size + off


func _joy_default() -> Vector2:
	return Vector2(size.x - 260, size.y - 230) if Settings.left_handed else Vector2(260, size.y - 230)


func _in_joy_zone(p: Vector2) -> bool:
	var left_zone := p.x < size.x * 0.45
	return (not left_zone if Settings.left_handed else left_zone) and p.y > size.y * 0.2


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var hit := _button_at(event.position)
			if hit != "":
				_btn_touch[event.index] = hit
				Input.action_press(hit)
			elif _in_joy_zone(event.position) and _joy_index == -1:
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
	elif event is InputEventScreenDrag and event.index == _joy_index:
		_joy_vec = ((event.position - _joy_origin) / JOY_R).limit_length(1.0)
		_apply_joy()


func _button_at(p: Vector2) -> String:
	for b in buttons:
		if p.distance_to(_btn_center(b)) <= b["r"] * _scale() * 1.15:
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
	for a in ["move_left", "move_right", "jump", "attack_light", "attack_heavy", "block", "power_1", "power_2", "swap"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	_btn_touch.clear()
	_joy_index = -1
	_joy_vec = Vector2.ZERO


func _draw() -> void:
	var op := Settings.button_opacity
	var sc := _scale()
	# joystick
	var base := _joy_origin if _joy_index != -1 else _joy_default()
	draw_circle(base, JOY_R * sc, Color(1, 1, 1, 0.07 * op))
	draw_arc(base, JOY_R * sc, 0, TAU, 48, Color(1, 1, 1, 0.3 * op), 4)
	draw_circle(base + _joy_vec * JOY_R * sc, 52 * sc, Color(1, 1, 1, 0.28 * op))
	for b in buttons:
		var c := _btn_center(b)
		var r: float = b["r"] * sc
		var pressed := _btn_touch.values().has(b["action"]) or Input.is_action_pressed(b["action"])
		var col: Color = b["color"]
		var ready := true
		if b.has("power") and fighter and b["power"] < fighter.powers.size():
			var cost := float(fighter.powers[b["power"]].get("cost", 30))
			var frac := clampf(fighter.energy / cost, 0.0, 1.0)
			ready = frac >= 1.0
			# energy ring
			draw_arc(c, r + 9, -PI / 2, -PI / 2 + TAU * frac, 48, Color(col, (0.95 if ready else 0.55) * op), 7.0)
			if ready:
				var pulse := 0.5 + 0.5 * sin(_t * 6.0)
				draw_circle(c, r + 14 + pulse * 6, Color(col, 0.10 * op))
		var fill := 0.38 if pressed else (0.16 if ready else 0.06)
		draw_circle(c, r, Color(0.02, 0.03, 0.06, 0.45 * op))
		draw_circle(c, r, Color(col, fill * op))
		draw_arc(c, r, 0, TAU, 40, Color(col, (0.8 if ready else 0.35) * op), 4)
		ButtonIcons.draw(self, b["icon"], c, r, Color(1, 1, 1, (0.92 if ready else 0.4) * op))
