extends Control
## Title screen: New Game, Continue, Chapter Select.

var _main: VBoxContainer
var _chapters: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("main_theme")
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.bg_id = "solar_altar"
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := Label.new()
	title.text = "THE CENTROID"
	title.set_anchor(SIDE_RIGHT, 1.0, true)
	title.set_anchor(SIDE_TOP, 0.1, true)
	title.set_anchor(SIDE_BOTTOM, 0.3, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 140)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.5))
	title.add_theme_constant_override("outline_size", 18)
	add_child(title)
	var sub := Label.new()
	sub.text = "37 days of darkness"
	sub.set_anchor(SIDE_RIGHT, 1.0, true)
	sub.set_anchor(SIDE_TOP, 0.3, true)
	sub.set_anchor(SIDE_BOTTOM, 0.36, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 40)
	sub.add_theme_color_override("font_color", Color(0.7, 0.65, 0.9))
	add_child(sub)

	_main = _column()
	_add_button(_main, "New Game", _new_game)
	if StoryManager.has_save():
		_add_button(_main, "Continue", func(): SceneRouter.go(StoryManager.resume_point))
	_add_button(_main, "Chapter Select", _open_chapters)

	_chapters = _column()
	_chapters.visible = false
	for i in StoryManager.CHAPTERS.size():
		var ch: Dictionary = StoryManager.CHAPTERS[i]
		var unlocked := StoryManager.is_chapter_unlocked(i)
		var b := _add_button(_chapters, ch["title"] if unlocked else "🔒  Locked", func(): SceneRouter.go(ch["start"]))
		b.disabled = not unlocked
		b.custom_minimum_size.x = 900
	_add_button(_chapters, "Back", func():
		_chapters.visible = false
		_main.visible = true)


func _column() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.set_anchor(SIDE_LEFT, 0.0, true)
	vb.set_anchor(SIDE_RIGHT, 1.0, true)
	vb.set_anchor(SIDE_TOP, 0.42, true)
	vb.set_anchor(SIDE_BOTTOM, 0.95, true)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.add_theme_constant_override("separation", 22)
	add_child(vb)
	return vb


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 104)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 46)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _new_game() -> void:
	StoryManager.new_game()
	SceneRouter.go({"type": "story", "id": "prologue"})


func _open_chapters() -> void:
	_main.visible = false
	_chapters.visible = true
