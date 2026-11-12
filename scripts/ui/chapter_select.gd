extends Control
## "37 Days" chapter select: progress across the top, chapter cards along a timeline.

var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("main_theme")
	var bg := Backdrop.new()
	bg.bg_id = "solar_altar"
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_Header.new())

	_scroll = ScrollContainer.new()
	_scroll.set_anchor(SIDE_LEFT, 0.0, true)
	_scroll.set_anchor(SIDE_RIGHT, 1.0, true)
	_scroll.set_anchor(SIDE_TOP, 0.24, true)
	_scroll.set_anchor(SIDE_BOTTOM, 0.97, true)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	_scroll.add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(40, 10)
	row.add_child(spacer)
	for i in StoryManager.CHAPTERS.size():
		var card := ChapterCard.new()
		card.index = i
		card.info = StoryManager.CHAPTERS[i]
		card.unlocked = StoryManager.is_chapter_unlocked(i)
		card.done = StoryManager.is_chapter_done(i)
		card.chosen.connect(_on_chosen)
		row.add_child(card)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(40, 10)
	row.add_child(spacer2)

	var back := Button.new()
	back.text = "◀  BACK"
	back.position = Vector2(36, 36)
	back.custom_minimum_size = Vector2(240, 90)
	back.pressed.connect(func(): SceneRouter.go({"type": "menu"}))
	add_child(back)


func _on_chosen(i: int) -> void:
	SceneRouter.go(StoryManager.CHAPTERS[i]["start"])


## Title + "Day X of 37" progress bar.
class _Header extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var tf := UiStyle.title_font()
		var uf := UiStyle.bold_font()
		var title := "THE 37 DAYS"
		var tw := tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
		draw_string(tf, Vector2(w / 2 - tw / 2, 110), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, UiStyle.GOLD)
		var reached := StoryManager.days_reached()
		var done := StoryManager.chapters_done()
		var sub := "PART ONE   ·   %d / 4 CHAPTERS   ·   DAY %d OF %d" % [done, reached, StoryManager.TOTAL_DAYS]
		var sw := uf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(uf, Vector2(w / 2 - sw / 2, 162), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiStyle.TEXT)
		# day track with markers for each chapter
		var x0 := w * 0.15
		var x1 := w * 0.85
		var y := 200.0
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.15), 6.0)
		var fx := x0 + (x1 - x0) * float(reached) / StoryManager.TOTAL_DAYS
		draw_line(Vector2(x0, y), Vector2(fx, y), UiStyle.GOLD, 6.0)
		for ch in StoryManager.CHAPTERS:
			var mx := x0 + (x1 - x0) * float(ch["day"]) / StoryManager.TOTAL_DAYS
			var lit := StoryManager.has_flag(ch["done"])
			draw_circle(Vector2(mx, y), 11.0, UiStyle.GOLD if lit else Color(0.3, 0.3, 0.36))
		var ex := x1
		draw_circle(Vector2(ex, y), 13.0, Color(1, 0.9, 0.6, 0.35))
		draw_string(uf, Vector2(ex + 22, y + 10), "DAY 37", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.MUTED)
