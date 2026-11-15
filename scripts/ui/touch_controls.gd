class_name TouchControls
extends Control
## Gesture controls, no buttons on screen (the fight stays clear):
##   swipe / drag toward or away from the opponent ... walk that way (held drag keeps walking)
##   quick flick toward the opponent ................. heavy attack
##   swipe up ........................................ jump
##   swipe down (tag fights) ......................... swap fighters
##   tap the opponent's side of the screen ........... light attack (tap again to chain the combo)
##   hold your own side .............................. block
##   hold the opponent's side ........................ fire the highest power whose bars are full
##                                                     (1, 2 or 3 bars; the third is unblockable)
## "Opponent's side" is the half of the screen the opponent is on. Feeds the same input actions
## as the keyboard (Input.action_press / action_release).

const MOVE_PX := 46.0       # drag distance before a touch becomes movement
const TAP_TIME := 0.24      # a tap is released within this
const FLICK_TIME := 0.2     # a flick is a short, fast swipe
const FLICK_PX := 90.0
const BLOCK_DELAY := 0.1    # holding your own side this long starts blocking
const POWER_HOLD := 0.45    # holding the opponent's side this long fires the power
const JUMP_PX := 90.0

var fighter: Fighter
var _touches := {}          # index -> {start, pos, t, opp, mode}
var _pulse := {}            # action -> frames left pressed
var _ripples: Array = []    # [pos, age, color]
var _t := 0.0
var _hint := 6.0            # first seconds of a fight: a one-line reminder of the gestures


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_fighter(f: Fighter) -> void:
	fighter = f
	queue_redraw()


## Which half of the screen the opponent is on (true = right).
func _opp_right() -> bool:
	if fighter and fighter.opponent:
		return fighter.opponent.position.x >= fighter.position.x
	return true


func _is_opp_side(p: Vector2) -> bool:
	return (p.x >= size.x * 0.5) == _opp_right()


func _toward_sign() -> float:
	return 1.0 if _opp_right() else -1.0


func _process(delta: float) -> void:
	_t += delta
	_hint = maxf(0.0, _hint - delta)
	for a in _pulse.keys():
		_pulse[a] -= 1
		if _pulse[a] <= 0:
			Input.action_release(a)
			_pulse.erase(a)
	for idx in _touches.keys():
		var tc: Dictionary = _touches[idx]
		var held: float = _t - tc["t"]
		if tc["mode"] == "pending":
			if not tc["opp"] and held >= BLOCK_DELAY:
				tc["mode"] = "block"
				Input.action_press("block")
			elif tc["opp"] and held >= POWER_HOLD:
				tc["mode"] = "done"
				if fighter and fighter.bars_full() > 0:
					_press_once("power")
					_ripples.append([tc["pos"], 0.0, fighter.color.lightened(0.3)])
				else:
					_ripples.append([tc["pos"], 0.0, Color(1, 1, 1, 0.4)])
	for r in _ripples:
		r[1] += delta
	_ripples = _ripples.filter(func(r): return r[1] < 0.45)
	queue_redraw()


func _press_once(action: String) -> void:
	Input.action_press(action)
	_pulse[action] = 2


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = {"start": event.position, "pos": event.position, "t": _t,
				"opp": _is_opp_side(event.position), "mode": "pending"}
		elif _touches.has(event.index):
			_release(event.index, event.position)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var tc: Dictionary = _touches[event.index]
		tc["pos"] = event.position
		var d: Vector2 = event.position - tc["start"]
		if tc["mode"] in ["pending", "block"]:
			if -d.y > JUMP_PX and absf(d.y) > absf(d.x) * 1.3:
				if tc["mode"] == "block":
					Input.action_release("block")
				tc["mode"] = "done"
				_press_once("jump")
			elif d.y > JUMP_PX and absf(d.y) > absf(d.x) * 1.3 and InputMap.has_action("swap"):
				if tc["mode"] == "block":
					Input.action_release("block")
				tc["mode"] = "done"
				_press_once("swap")   # tag fights: swipe down swaps fighters
			elif absf(d.x) > MOVE_PX:
				if tc["mode"] == "block":
					Input.action_release("block")
				tc["mode"] = "move"
		if tc["mode"] == "move":
			_apply_move(d.x)


func _release(idx: int, pos: Vector2) -> void:
	var tc: Dictionary = _touches[idx]
	var held: float = _t - tc["t"]
	var d: Vector2 = pos - tc["start"]
	match tc["mode"]:
		"pending":
			if held <= TAP_TIME and tc["opp"]:
				_press_once("attack_light")
				_ripples.append([pos, 0.0, Color(1, 1, 1, 0.5)])
		"block":
			Input.action_release("block")
		"move":
			_apply_move(0.0)
			if held <= FLICK_TIME and absf(d.x) > FLICK_PX and signf(d.x) == _toward_sign():
				_press_once("attack_heavy")
				_ripples.append([pos, 0.0, Color(1.0, 0.75, 0.45, 0.6)])
	_touches.erase(idx)


func _apply_move(dx: float) -> void:
	if dx < -MOVE_PX * 0.5:
		Input.action_press("move_left")
		Input.action_release("move_right")
	elif dx > MOVE_PX * 0.5:
		Input.action_press("move_right")
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func release_all() -> void:
	for a in ["move_left", "move_right", "jump", "attack_light", "attack_heavy", "block", "power", "power_1",
			"power_2", "power_3", "swap"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	_touches.clear()
	_pulse.clear()


func _draw() -> void:
	var op := Settings.button_opacity
	# finger feedback only: a ring under a held finger, and a charge arc while holding for a power
	for idx in _touches:
		var tc: Dictionary = _touches[idx]
		var p: Vector2 = tc["pos"]
		var held: float = _t - tc["t"]
		match tc["mode"]:
			"block":
				draw_arc(p, 54, 0, TAU, 40, Color(0.6, 0.8, 1.0, 0.45 * op), 5.0)
			"pending":
				if tc["opp"] and held > 0.08 and fighter:
					var k := clampf((held - 0.08) / (POWER_HOLD - 0.08), 0.0, 1.0)
					var bars := fighter.bars_full()
					var col := fighter.color.lightened(0.3) if bars > 0 else Color(1, 1, 1, 0.5)
					draw_arc(p, 60, -PI / 2, -PI / 2 + TAU * k, 48, Color(col, 0.85 * op), 7.0)
					if bars > 0:
						var f := UiStyle.bold_font()
						draw_string(f, p + Vector2(-60, -78), "POWER %d" % bars, HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color(col, op))
	for r in _ripples:
		var k2: float = r[1] / 0.45
		draw_arc(r[0], 30 + 70 * k2, 0, TAU, 40, Color(r[2], (1.0 - k2) * 0.8 * op), 4.0)
	if _hint > 0.0:
		var a := clampf(_hint, 0.0, 1.0) * op
		# a manga caption box: ink black with a white frame
		var f2 := Ink.label_font()
		var txt := "SWIPE to move  ·  TAP their side to attack  ·  HOLD your side to block  ·  HOLD their side for POWER"
		var tw := f2.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var box := Rect2(size.x / 2 - tw / 2 - 28, size.y - 92, tw + 56, 58)
		draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(0, 0, 0, 0.6 * a))
		draw_rect(box, Color(Ink.INK, 0.92 * a))
		draw_rect(box.grow(-5), Color(1, 1, 1, 0.85 * a), false, 2.0)
		draw_string(f2, Vector2(box.position.x, box.position.y + 39), txt, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 26, Color(1, 1, 1, a))
