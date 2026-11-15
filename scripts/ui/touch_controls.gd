class_name TouchControls
extends Control
## Gesture controls, no buttons on screen (the fight stays clear):
##   swipe / drag toward or away from the opponent ... walk that way (held drag keeps walking)
##   quick flick toward the opponent ................. heavy attack
##   swipe up ........................................ jump
##   swipe down (tag fights) ......................... swap fighters
##   tap the opponent's side of the screen ........... light attack (tap again to chain the combo)
##   hold your own side .............................. block
##   tap the POWER GAUGE (bottom corner, your side) .. fire the highest power whose bars are full
##                                                     (1, 2 or 3 bars; the third is unblockable)
## "Opponent's side" is the half of the screen the opponent is on. No touch markers are drawn:
## the only control on screen is the power gauge (MCOC style). Feeds the same input actions as
## the keyboard (Input.action_press / action_release).

const MOVE_PX := 46.0       # drag distance before a touch becomes movement
const TAP_TIME := 0.24      # a tap is released within this
const FLICK_TIME := 0.2     # a flick is a short, fast swipe
const FLICK_PX := 90.0
const BLOCK_DELAY := 0.1    # holding your own side this long starts blocking
const JUMP_PX := 90.0

var fighter: Fighter
var _touches := {}          # index -> {start, pos, t, opp, mode}
var _pulse := {}            # action -> frames left pressed
var _gauge_flash := 0.0     # the gauge punches when tapped
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
		if tc["mode"] == "pending" and not tc["opp"] and held >= BLOCK_DELAY:
			tc["mode"] = "block"
			Input.action_press("block")
	_gauge_flash = maxf(0.0, _gauge_flash - delta * 4.0)
	queue_redraw()


## The power gauge: bottom corner on the player's side (the right corner for left-handed play).
func gauge_rect() -> Rect2:
	var k := Settings.button_scale
	var gs := Vector2(500, 150) * k
	var x := size.x - gs.x - 30.0 if Settings.left_handed else 30.0
	return Rect2(Vector2(x, size.y - gs.y - 26.0), gs)


func _tap_gauge() -> void:
	_gauge_flash = 1.0
	if fighter and fighter.bars_full() > 0:
		_press_once("power")


func _press_once(action: String) -> void:
	Input.action_press(action)
	_pulse[action] = 2


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var on_gauge := gauge_rect().grow(16.0).has_point(event.position)
			_touches[event.index] = {"start": event.position, "pos": event.position, "t": _t,
				"opp": _is_opp_side(event.position), "mode": "gauge" if on_gauge else "pending"}
			if on_gauge:
				_tap_gauge()
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
		"block":
			Input.action_release("block")
		"move":
			_apply_move(0.0)
			if held <= FLICK_TIME and absf(d.x) > FLICK_PX and signf(d.x) == _toward_sign():
				_press_once("attack_heavy")
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
	if fighter:
		# yours (tap it) in your corner, the opponent's mirrored in theirs so you can see it coming
		_draw_gauge(fighter, gauge_rect(), Settings.left_handed, true, op)
		if fighter.opponent:
			var g := gauge_rect()
			var er := Rect2(Vector2(size.x - g.end.x, g.position.y), g.size)
			_draw_gauge(fighter.opponent, er, not Settings.left_handed, false, op * 0.9)
	if _hint > 0.0:
		# a manga caption box above the gauges: ink black with a white frame
		var a := clampf(_hint, 0.0, 1.0) * op
		var f2 := Ink.label_font()
		var txt := "SWIPE to move  ·  TAP their side to attack  ·  HOLD your side to block  ·  TAP your POWER gauge"
		var tw := f2.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var box := Rect2(size.x / 2 - tw / 2 - 28, gauge_rect().position.y - 80, tw + 56, 58)
		draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(0, 0, 0, 0.6 * a))
		draw_rect(box, Color(Ink.INK, 0.92 * a))
		draw_rect(box.grow(-5), Color(1, 1, 1, 0.85 * a), false, 2.0)
		draw_string(f2, Vector2(box.position.x, box.position.y + 39), txt, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 26, Color(1, 1, 1, a))


## MCOC-style special meter: a round emblem with the number of full bars, three slanted bars
## filling toward the next power, and the name of the power that fires next. `right` puts the
## emblem on the right (bars fill toward the centre); `mine` = the player's (tap it).
func _draw_gauge(f: Fighter, r: Rect2, right: bool, mine: bool, op: float) -> void:
	var k := Settings.button_scale
	var bars := f.bars_full()
	var e := f.energy / Fighter.MAX_ENERGY
	var col := f.color
	var ready := bars > 0
	var pulse := 0.5 + 0.5 * sin(_t * 6.0) if ready else 0.0
	var punch := 1.0 + 0.12 * (_gauge_flash if mine else 0.0)
	# emblem
	var er := r.size.y * 0.42 * punch
	var ec := Vector2(r.end.x - r.size.y * 0.45 if right else r.position.x + r.size.y * 0.45, r.position.y + r.size.y * 0.52)
	if ready:
		draw_circle(ec, er * (1.25 + 0.1 * pulse), Color(col, 0.25 * op))
	draw_circle(ec + Vector2(6, 6) * k, er, Color(0, 0, 0, 0.8 * op))
	draw_circle(ec, er, Color(col.lightened(0.15), op) if ready else Color(0.22, 0.22, 0.28, op))
	draw_arc(ec, er, 0, TAU, 48, Color(Ink.INK, op), 6.0 * k, true)
	draw_arc(ec, er - 7 * k, 0, TAU, 48, Color(1, 1, 1, 0.8 * op), 2.0 * k, true)
	var lf := Ink.letter_font()
	var num := str(bars)
	var nfs := int(er * 1.25)
	var nw := lf.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	draw_string_outline(lf, ec + Vector2(-nw / 2, nfs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, int(nfs * 0.16), Color(Ink.INK, op))
	draw_string(lf, ec + Vector2(-nw / 2, nfs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(1, 1, 1, op))
	# three bars, filling outward from the emblem
	var bars_w := r.size.x - r.size.y * 0.95
	var bx0 := r.position.x if right else r.position.x + r.size.y * 0.95
	var bw := bars_w / 3.0
	var by := r.position.y + r.size.y * 0.56
	var bh := r.size.y * 0.26
	var dir := -1 if right else 1
	for i in 3:
		var seg := clampf(e * 3.0 - i, 0.0, 1.0)
		var c2 := col.lightened(0.15)
		if seg >= 1.0:
			c2 = c2.lerp(Color.WHITE, 0.2 + 0.25 * pulse)
		var slot := (2 - i) if right else i
		var sr := Rect2(bx0 + slot * bw + 4, by, bw - 10, bh)
		Metal.slant_bar(self, sr, seg, Color(c2.lightened(0.3), op), Color(c2.darkened(0.2), op), -1.0, dir, 10.0, Color(1, 1, 1, 0.5 * op))
	# what fires next
	var label := "CHARGING..."
	if ready and bars - 1 < f.powers.size():
		var pname := String(f.powers[bars - 1].get("name", "POWER")).to_upper()
		label = ("TAP  ·  " + pname) if mine else pname
	var lfs := int(30 * k)
	var lw := lf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var lx := (bx0 + bars_w - 4 - lw) if right else (bx0 + 4)
	Ink.shout(self, Vector2(lx, by - 14 * k), label, lfs, Color(1, 1, 1, op if ready else 0.6 * op),
		Color(col, op) if ready else Color(0.3, 0.3, 0.35, op), false, 0.0)
