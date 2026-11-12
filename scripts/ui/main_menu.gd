extends Control
## Title screen over the animated eclipse wallpaper.

var _confirm: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("main_theme")
	var bg := Backdrop.new()
	bg.bg_id = "title"
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_Logo.new())

	var row := HBoxContainer.new()
	row.set_anchor(SIDE_LEFT, 0.0, true)
	row.set_anchor(SIDE_RIGHT, 1.0, true)
	row.set_anchor(SIDE_TOP, 0.865, true)
	row.set_anchor(SIDE_BOTTOM, 0.97, true)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	add_child(row)
	if StoryManager.has_save():
		_add(row, "CONTINUE", func(): SceneRouter.go(StoryManager.resume_point))
	_add(row, "NEW GAME", _new_game)
	_add(row, "CHAPTERS", func(): SceneRouter.go({"type": "chapters"}))
	_add(row, "SETTINGS", func(): add_child(SettingsPanel.new()))


func _add(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(330, 96)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _new_game() -> void:
	if not StoryManager.has_save():
		_start_new()
		return
	# confirm before wiping progress
	_confirm = Control.new()
	add_child(_confirm)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	_confirm.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 30)
	_confirm.add_child(vb)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var l := Label.new()
	l.text = "Start a new game? Your current progress will be lost."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 44)
	vb.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 30)
	vb.add_child(hb)
	_add(hb, "START OVER", _start_new)
	_add(hb, "CANCEL", func(): _confirm.queue_free())


func _start_new() -> void:
	StoryManager.new_game()
	SceneRouter.go({"type": "story", "id": "prologue"})


class _Logo extends Control:
	var t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var tf := UiStyle.title_font()
		var title := "THE CENTROID"
		var fs := int(h * 0.12)
		var tw := tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(w / 2 - tw / 2, h * 0.40)
		var glow := 0.5 + 0.2 * sin(t * 1.3)
		draw_string_outline(tf, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 26, Color(0.55, 0.42, 1.0, 0.18 * glow))
		draw_string_outline(tf, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.9))
		draw_string(tf, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.93, 0.95, 1.0))
		var sub := "37  DAYS  OF  DARKNESS"
		var uf := UiStyle.bold_font()
		var ss := int(h * 0.035)
		var sw := uf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		draw_string_outline(uf, Vector2(w / 2 - sw / 2, h * 0.47), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, 8, Color(0, 0, 0, 0.9))
		draw_string(uf, Vector2(w / 2 - sw / 2, h * 0.47), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, UiStyle.GOLD)
		var tag := "PART ONE"
		var gw := uf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(uf, Vector2(w / 2 - gw / 2, h * 0.52), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.55))
