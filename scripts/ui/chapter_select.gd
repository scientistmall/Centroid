extends Control
## Quest-map chapter select: a glowing path of metal hex nodes (one per chapter)
## and a detail panel with the matchup and a PLAY button. Keeps the 37 Days progress.

var selected := 0
var _t := 0.0
var _nodes: Array[Vector2] = []
var _play: Button
var _portraits: Array = []
var _map: _Map


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("main_theme")
	var bg := Backdrop.new()
	bg.bg_id = "solar_altar"
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map = _Map.new()
	_map.cs = self
	add_child(_map)
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# portraits in the detail panel
	for i in 2:
		var p := Portrait.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.clip_contents = true
		add_child(p)
		_portraits.append(p)
	_play = Button.new()
	_play.theme_type_variation = "PrimaryButton"
	_play.add_theme_font_size_override("font_size", 64)
	_play.pressed.connect(func(): SceneRouter.go(StoryManager.CHAPTERS[selected]["start"]))
	add_child(_play)
	var back := Button.new()
	back.text = "◀  BACK"
	back.position = Vector2(30, 24)
	back.custom_minimum_size = Vector2(250, 92)
	back.pressed.connect(func(): SceneRouter.go({"type": "menu"}))
	add_child(back)
	# start on the first chapter that isn't completed yet
	selected = 0
	for i in StoryManager.CHAPTERS.size():
		if StoryManager.is_chapter_unlocked(i):
			selected = i
			if not StoryManager.is_chapter_done(i):
				break
	_select(selected)


func _layout_nodes() -> void:
	var w := size.x
	var h := size.y
	_nodes.clear()
	var n := StoryManager.CHAPTERS.size()
	for i in n:
		var x := w * 0.08 + i * (w * 0.50 / maxf(1.0, n - 1.0))
		var y := h * 0.56 + sin(i * 1.4 + 0.4) * h * 0.17
		_nodes.append(Vector2(x, y))


func _select(i: int) -> void:
	selected = i
	var ch: Dictionary = StoryManager.CHAPTERS[i]
	var unlocked := StoryManager.is_chapter_unlocked(i)
	var done := StoryManager.is_chapter_done(i)
	var f: Array = ch.get("fighters", [])
	for k in 2:
		var p: Portrait = _portraits[k]
		p.set_character(f[k] if k < f.size() else "", k == 1)
		p.set_expression("determined" if k == 0 else "angry")
		p.modulate = Color.WHITE if unlocked else Color(0.25, 0.25, 0.3)
	_play.text = "LOCKED" if not unlocked else ("REPLAY" if done else "PLAY")
	_play.disabled = not unlocked
	_relayout_detail()


func _relayout_detail() -> void:
	if _portraits.size() < 2 or _play == null:
		return
	var w := size.x
	var h := size.y
	var px := w * 0.64
	var pw := w * 0.33
	for k in 2:
		var p: Portrait = _portraits[k]
		p.size = Vector2(pw * 0.5, h * 0.36)
		p.position = Vector2(px + k * pw * 0.5, h * 0.35)
	_play.position = Vector2(px + pw * 0.15, h * 0.80)
	_play.size = Vector2(pw * 0.7, 110)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_nodes()
		_relayout_detail()


func _process(delta: float) -> void:
	_t += delta
	_map.queue_redraw()


class _Map extends Control:
	var cs

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			for i in cs._nodes.size():
				if event.position.distance_to(cs._nodes[i]) < 90.0:
					AudioManager.sfx("ui_click")
					cs._select(i)
					accept_event()
					return

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if cs._nodes.is_empty():
			cs._layout_nodes()
		draw_rect(Rect2(0, 0, w, h), Color(0.01, 0.015, 0.03, 0.86))
		# faint contour lines (map feel)
		for k in 9:
			var pts := PackedVector2Array()
			for i in 40:
				var x := w * i / 39.0
				pts.append(Vector2(x, h * (0.25 + k * 0.08) + sin(x * 0.004 + k) * 22.0))
			draw_polyline(pts, Color(0.5, 0.6, 0.9, 0.05), 2.0)
		# header bar
		Metal.panel(self, Rect2(-20, 0, w + 40, 132), Metal.GOLD, 0.0, Color("2a303c"), Color("0b0d12"), 0.4, [false, false, false, false])
		Metal.shout(self, Vector2(w / 2, 92), "THE 37 DAYS  ·  PART ONE", 84, Color.WHITE, Metal.GOLD)
		var day := StoryManager.days_reached()
		Metal.shout(self, Vector2(w - 560, 84), "DAY %d / %d" % [day, StoryManager.TOTAL_DAYS], 48, Metal.GOLD, Metal.GOLD, false)
		Metal.slant_bar(self, Rect2(w - 330, 50, 290, 34), float(day) / StoryManager.TOTAL_DAYS, Color("ffe08a"), Color("b07a22"), -1.0, 1, 10.0, Color(1, 1, 1, 0.5))
		# path
		var nodes: Array = cs._nodes
		for i in range(1, nodes.size()):
			var done: bool = StoryManager.is_chapter_done(i - 1)
			var open: bool = StoryManager.is_chapter_unlocked(i)
			var col := Metal.GOLD if done and StoryManager.is_chapter_done(i) else (Metal.CYAN if open else Color(0.35, 0.35, 0.42))
			if open and not StoryManager.is_chapter_done(i):
				col = col.lerp(Color.WHITE, 0.25 + 0.25 * sin(cs._t * 4.0))
			draw_line(nodes[i - 1], nodes[i], Color(col, 0.25), 22.0)
			draw_line(nodes[i - 1], nodes[i], col, 6.0)
		# nodes
		for i in nodes.size():
			var ch: Dictionary = StoryManager.CHAPTERS[i]
			var unlocked := StoryManager.is_chapter_unlocked(i)
			var done2 := StoryManager.is_chapter_done(i)
			var sel: bool = i == cs.selected
			var r := 70.0 if sel else 58.0
			var c: Vector2 = nodes[i]
			var trim := Metal.GOLD if done2 else (Metal.CYAN if unlocked else Color(0.4, 0.4, 0.45))
			if sel:
				for g in 3:
					draw_arc(c, r + 16 + g * 8 + 4 * sin(cs._t * 3.0), 0, TAU, 40, Color(trim, 0.3 - g * 0.08), 4.0)
			Metal.panel(self, Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)), trim, r * 0.42, Color("3b4352"), Color("10131a"), 0.5, [true, true, true, true])
			var lbl := "P" if i == 0 else str(i)
			Metal.shout(self, c + Vector2(0, r * 0.42), lbl, int(r * 1.15), Color.WHITE if unlocked else Color(0.5, 0.5, 0.55), trim)
			var day_lbl: String = ch.get("day_label", "")
			Metal.shout(self, c + Vector2(0, r + 46), day_lbl, 38, trim, trim)
		# detail panel
		var px := w * 0.64
		var pw := w * 0.33
		var panel := Rect2(px - 20, h * 0.17, pw + 40, h * 0.80)
		Metal.panel(self, panel, Metal.CYAN, 30.0, Color("262c38"), Color("0b0d12"), 0.5)
		var sel_ch: Dictionary = StoryManager.CHAPTERS[cs.selected]
		Metal.shout(self, Vector2(px + 10, h * 0.25), String(sel_ch.get("short", "")) + "  ·  " + String(sel_ch.get("day_label", "")), 52, Metal.GOLD, Metal.GOLD, false)
		var tf := UiStyle.bold_font()
		draw_string(tf, Vector2(px + 12, h * 0.31), String(sel_ch.get("place", "")), HORIZONTAL_ALIGNMENT_LEFT, pw, 38, Color(0.85, 0.9, 1.0))
		Metal.shout(self, Vector2(px + pw / 2, h * 0.60), "VS", 90, Metal.GOLD, Metal.GOLD)
		var status := "COMPLETED" if StoryManager.is_chapter_done(cs.selected) else ("NEW" if StoryManager.is_chapter_unlocked(cs.selected) else "LOCKED")
		Metal.shout(self, Vector2(px + pw / 2, h * 0.775), status, 46, Metal.GOLD if status == "COMPLETED" else (Metal.CYAN if status == "NEW" else Color(0.6, 0.6, 0.65)), Metal.CYAN)
