extends Control
## Title screen (heavy-metal style): logo + big metal button stack on the left,
## hero portraits on the right, progress plaque, eclipse wallpaper behind.

var _confirm: Control
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("main_theme")
	var bg := Backdrop.new()
	bg.bg_id = "title"
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := _Shade.new()
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# hero portraits (replaced by 3D model renders once the models arrive)
	for i in 2:
		var p := Portrait.new()
		add_child(p)
		p.set_character(["rhex", "kael"][i], true)
		p.set_expression(["angry", "determined"][i])
		p.modulate = Color(0.55, 0.5, 0.55) if i == 0 else Color.WHITE
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vs := get_viewport().get_visible_rect().size
		var sz := Vector2(vs.y * 0.82, vs.y * 1.0) * (0.85 if i == 0 else 1.0)
		p.size = sz
		p.position = Vector2(vs.x - sz.x - (vs.y * 0.42 if i == 0 else vs.y * 0.02), vs.y - sz.y * (0.92 if i == 0 else 0.95))

	add_child(_Logo.new())
	var col := VBoxContainer.new()
	col.set_anchor(SIDE_LEFT, 0.05, true)
	col.set_anchor(SIDE_RIGHT, 0.36, true)
	col.set_anchor(SIDE_TOP, 0.38, true)
	col.set_anchor(SIDE_BOTTOM, 0.95, true)
	col.add_theme_constant_override("separation", 22)
	add_child(col)
	if StoryManager.has_save():
		_add(col, "CONTINUE", func(): SceneRouter.go(StoryManager.resume_point), true)
		_add(col, "NEW GAME", _new_game)
	else:
		_add(col, "START STORY", _new_game, true)
	_add(col, "CHAPTERS", func(): SceneRouter.go({"type": "chapters"}))
	_add(col, "SETTINGS", func(): add_child(SettingsPanel.new()))
	var plaque := _Plaque.new()
	add_child(plaque)
	plaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _add(parent: Control, text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 112)
	b.add_theme_font_size_override("font_size", 64 if primary else 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _new_game() -> void:
	if not StoryManager.has_save():
		_start_new()
		return
	_confirm = Control.new()
	add_child(_confirm)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	_confirm.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.set_anchor(SIDE_LEFT, 0.25, true)
	panel.set_anchor(SIDE_RIGHT, 0.75, true)
	panel.set_anchor(SIDE_TOP, 0.3, true)
	panel.set_anchor(SIDE_BOTTOM, 0.7, true)
	_confirm.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 30)
	panel.add_child(vb)
	var l := Label.new()
	l.text = "Start a new game? Your current progress will be lost."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 40)
	vb.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 30)
	vb.add_child(hb)
	var a := _add(hb, "START OVER", _start_new, true)
	a.custom_minimum_size = Vector2(320, 100)
	var c := _add(hb, "CANCEL", func(): _confirm.queue_free())
	c.custom_minimum_size = Vector2(260, 100)


func _start_new() -> void:
	StoryManager.new_game()
	SceneRouter.go({"type": "story", "id": "prologue"})


## Darkens the left side so the buttons read clearly.
class _Shade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.55, 0), Vector2(w * 0.42, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.82)]))


class _Logo extends Control:
	var t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var x := size.x * 0.05
		var tf := UiStyle.title_font()
		var fs := int(h * 0.105)
		var glow := 0.5 + 0.2 * sin(t * 1.3)
		var p := Vector2(x, h * 0.20)
		draw_string_outline(tf, p, "THE CENTROID", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 26, Color(0.55, 0.42, 1.0, 0.18 * glow))
		draw_string_outline(tf, p, "THE CENTROID", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.9))
		draw_string(tf, p, "THE CENTROID", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.96, 1.0))
		Metal.shout(self, Vector2(x, h * 0.28), "37 DAYS OF DARKNESS  ·  PART ONE", int(h * 0.045), Metal.GOLD, Metal.GOLD, false)


## Progress plaque, bottom right.
class _Plaque extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := Rect2(w - 620, h - 120, 590, 92)
		Metal.panel(self, r, Metal.GOLD, 20.0, Color("2a303c"), Color("0b0d12"), 0.5)
		var done := StoryManager.chapters_done()
		var day := StoryManager.days_reached()
		Metal.shout(self, Vector2(r.position.x + 30, r.position.y + 70), "DAY %d / %d" % [day, StoryManager.TOTAL_DAYS], 56, Color.WHITE, Metal.GOLD, false)
		var bx := r.position.x + 300
		Metal.slant_bar(self, Rect2(bx, r.position.y + 30, 260, 34), float(done) / 4.0, Color("ffe08a"), Color("b07a22"), -1.0, 1, 10.0, Color(1, 1, 1, 0.5))
