class_name Briefing
extends Control
## Blueprint-style battle briefing shown before every fight (and from the pause menu).
## Left: your buttons, each with an animated diagram of what it does.
## Right: the enemy's powers, and how to counter them (enemy power -> your buttons).
## Explanations are visual; text is limited to names.

signal closed

const INK := Color("cfe8ff")
const BG := Color("0a1d38")

var player: Dictionary = {}
var enemy: Dictionary = {}
var counters: Array = []
var _t := 0.0
var _rows: Array = []   # [{rect, icon, color, caption}] drawn by this control (icons + captions)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	_layout()


func _cell(rect: Rect2, icon: String, icon_col: Color, caption: String, demo: BlueprintDemo) -> void:
	var icon_r := minf(rect.size.y * 0.22, 48.0)
	_rows.append({"c": rect.position + Vector2(icon_r + 6, rect.size.y * 0.42), "r": icon_r, "icon": icon, "col": icon_col, "caption": caption,
		"cap_pos": rect.position + Vector2(0, rect.size.y + 34)})
	demo.position = rect.position + Vector2(icon_r * 2 + 22, 0)
	demo.size = Vector2(rect.size.x - icon_r * 2 - 22, rect.size.y)
	add_child(demo)


func _demo_move(data: Dictionary, action) -> BlueprintDemo:
	var d := BlueprintDemo.new()
	d.actor = data
	d.action = action
	return d


func _layout() -> void:
	var w := size.x
	var h := size.y
	var pcol := Color(player.get("color", "#ffffff"))
	var ecol := Color(enemy.get("color", "#ff6644"))
	var moves: Dictionary = player.get("moves", {})
	var ppow: Array = player.get("powers", [])
	var epow: Array = enemy.get("powers", [])

	# ---- your moves: 3 x 2 grid
	var lx := w * 0.03
	var lw := w * 0.45
	var top := h * 0.20
	var cw := lw / 3.0
	var ch := h * 0.25
	var items := [
		["attack_light", Color(0.9, 0.92, 1.0), "×%d" % moves.get("light", []).size(), moves.get("light", [{}])[0]],
		["attack_heavy", Color(1.0, 0.72, 0.42), "×%d" % moves.get("heavy", []).size(), moves.get("heavy", [{}])[0]],
		["block", Color(0.62, 0.8, 1.0), "", "block"],
		["jump", Color(0.6, 1.0, 0.72), "", "jump"],
	]
	for i in 2:
		if i < ppow.size():
			items.append([ButtonIcons.for_power(ppow[i]), pcol.lightened(0.2), String(ppow[i].get("name", "")), ppow[i]])
	for i in items.size():
		var it: Array = items[i]
		var r := Rect2(lx + (i % 3) * cw, top + (i / 3) * (ch + 70), cw - 24, ch)
		_cell(r, it[0], it[1], it[2], _demo_move(player, it[3]))

	# ---- enemy powers: 2 cells
	var rx := w * 0.52
	var rw := w * 0.45
	for i in mini(2, epow.size()):
		var r2 := Rect2(rx + i * (rw / 2.0), top, rw / 2.0 - 24, ch)
		_cell(r2, ButtonIcons.for_power(epow[i]), ecol, String(epow[i].get("name", "")), _demo_move(enemy, epow[i]))

	# ---- counters: enemy power -> your answer buttons, with an animated answer
	var cy := top + ch + 120
	for k in mini(2, counters.size()):
		var cdef: Dictionary = counters[k]
		var threat := {}
		for p in epow:
			if p.get("id", "") == cdef.get("threat", ""):
				threat = p
		var answers: Array = cdef.get("answers", [])
		var demo := BlueprintDemo.new()
		demo.mode = "counter"
		demo.actor = player
		demo.foe = enemy
		demo.threat = threat
		demo.answer = _demo_answer(answers[0] if answers.size() > 0 else "block")
		var r3 := Rect2(rx + 300, cy + k * (ch * 0.74 + 18), rw - 300, ch * 0.74)
		demo.position = r3.position
		demo.size = r3.size
		add_child(demo)
		var icons: Array = []
		for a in answers:
			icons.append(_answer_icon(a))
		_rows.append({"counter": true, "y": r3.position.y + r3.size.y * 0.5, "x": rx, "threat_icon": ButtonIcons.for_power(threat),
			"answers": icons, "ecol": ecol, "pcol": pcol})


func _demo_answer(a: String) -> String:
	if a.begins_with("power_"):
		var i := int(a.substr(6)) - 1
		var ppow: Array = player.get("powers", [])
		if i < ppow.size() and ppow[i].get("type", "") == "dash":
			return "dash"
		return a
	return a


func _answer_icon(a: String) -> Array:
	match a:
		"jump": return ["jump", Color(0.6, 1.0, 0.72)]
		"block": return ["block", Color(0.62, 0.8, 1.0)]
		"back": return ["back", Color(0.85, 0.85, 0.9)]
		"attack_light": return ["attack_light", Color(0.9, 0.92, 1.0)]
		"attack_heavy": return ["attack_heavy", Color(1.0, 0.72, 0.42)]
	if a.begins_with("power_"):
		var i := int(a.substr(6)) - 1
		var ppow: Array = player.get("powers", [])
		if i < ppow.size():
			return [ButtonIcons.for_power(ppow[i]), Color(player.get("color", "#ffffff")).lightened(0.2)]
	return ["burst", Color.WHITE]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if tap and _t > 0.6:
		accept_event()
		AudioManager.sfx("ui_confirm")
		closed.emit()
		queue_free()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), BG)
	# blueprint grid
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h), Color(INK, 0.12 if int(x) % 200 == 0 else 0.05), 1.0)
		x += 40.0
	var y := 0.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), Color(INK, 0.12 if int(y) % 200 == 0 else 0.05), 1.0)
		y += 40.0
	var tf := UiStyle.title_font()
	var uf := UiStyle.bold_font()
	# header
	var title := "BATTLE BRIEFING"
	var tw := tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x
	draw_string(tf, Vector2(w / 2 - tw / 2, 82), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, INK)
	var pn := String(player.get("name", ""))
	var en := String(enemy.get("name", ""))
	var vs := "%s   VS   %s" % [pn, en]
	var vw := uf.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var vx := w / 2 - vw / 2
	draw_string(uf, Vector2(vx, 140), pn, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(player.get("color", "#ffffff")))
	draw_string(uf, Vector2(vx + uf.get_string_size(pn + "   ", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x, 140), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(INK, 0.6))
	draw_string(uf, Vector2(vx + uf.get_string_size(pn + "   VS   ", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x, 140), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(enemy.get("color", "#ff6644")))
	# section rules
	draw_line(Vector2(w * 0.5, h * 0.18), Vector2(w * 0.5, h * 0.92), Color(INK, 0.3), 2.0)
	_section(Vector2(w * 0.03, h * 0.18), "YOUR BUTTONS", uf)
	_section(Vector2(w * 0.52, h * 0.18), "ENEMY POWERS", uf)
	_section(Vector2(w * 0.52, h * 0.20 + h * 0.25 + 100), "COUNTERS", uf)
	# icons, captions and counter rows
	for row in _rows:
		if row.get("counter", false):
			var cy: float = row["y"]
			var x0: float = row["x"] + 50
			draw_circle(Vector2(x0, cy), 44, Color(0.02, 0.05, 0.12))
			draw_arc(Vector2(x0, cy), 44, 0, TAU, 32, row["ecol"], 3.0)
			ButtonIcons.draw(self, row["threat_icon"], Vector2(x0, cy), 44, row["ecol"])
			draw_line(Vector2(x0 + 52, cy), Vector2(x0 + 110, cy), INK, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x0 + 122, cy), Vector2(x0 + 106, cy - 9), Vector2(x0 + 106, cy + 9)]), INK)
			var ans: Array = row["answers"]
			for i in ans.size():
				var c := Vector2(x0 + 170 + i * 72, cy + (i - (ans.size() - 1) / 2.0) * 0.0)
				var col: Color = ans[i][1]
				draw_circle(c, 32, Color(col, 0.18))
				draw_arc(c, 32, 0, TAU, 28, col, 3.0)
				if ans[i][0] == "back":
					_draw_back(c, 32, col)
				else:
					ButtonIcons.draw(self, ans[i][0], c, 32, Color.WHITE)
			continue
		var c2: Vector2 = row["c"]
		var r: float = row["r"]
		draw_circle(c2, r, Color(0.02, 0.05, 0.12))
		draw_circle(c2, r, Color(row["col"], 0.16))
		draw_arc(c2, r, 0, TAU, 32, row["col"], 3.0)
		ButtonIcons.draw(self, row["icon"], c2, r, Color.WHITE)
		if row["caption"] != "":
			draw_string(uf, row["cap_pos"], row["caption"], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(INK, 0.85))
	# footer
	var a := 0.5 + 0.4 * sin(_t * 4.0)
	var foot := "TAP TO FIGHT"
	var fw := uf.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	draw_string(uf, Vector2(w / 2 - fw / 2, h - 40), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1, 1, 1, a))


func _section(p: Vector2, text: String, f: Font) -> void:
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(INK, 0.7))
	draw_line(p + Vector2(0, 8), p + Vector2(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x, 8), Color(INK, 0.4), 2.0)


## "Move back" icon: a bold left arrow (push the joystick away from the enemy).
func _draw_back(c: Vector2, r: float, _col: Color) -> void:
	var s := r * 0.55
	draw_line(c + Vector2(s, 0), c + Vector2(-s * 0.4, 0), Color.WHITE, 5.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s * 0.3, -s * 0.6), c + Vector2(-s * 0.3, s * 0.6)]), Color.WHITE)
