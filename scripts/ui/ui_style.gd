class_name UiStyle
extends RefCounted
## Shared look for all menus: fonts, colours and button styles.

const ACCENT := Color("8fd8ff")
const GOLD := Color("f2d27a")
const PANEL := Color(0.03, 0.04, 0.08, 0.86)
const TEXT := Color("e8ecf6")
const MUTED := Color("8a90a8")

static var _title_font: Font
static var _ui_font: Font
static var _bold_font: Font
static var _theme: Theme


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/Cinzel-Bold.woff2")
	return _title_font


static func ui_font() -> Font:
	if _ui_font == null:
		_ui_font = load("res://assets/fonts/Rajdhani-SemiBold.woff2")
	return _ui_font


static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = load("res://assets/fonts/Rajdhani-Bold.woff2")
	return _bold_font


static var _sharp := {}


## A multichannel signed-distance-field copy of `f`: stays crisp when its node is scaled
## (the story's page camera zooms panels), where a normal font would be stretched and blurred.
static func sharp(f: Font) -> Font:
	if not (f is FontFile):
		return f
	var key := f.resource_path if f.resource_path != "" else str(f.get_instance_id())
	if not _sharp.has(key):
		var n := FontFile.new()
		n.data = (f as FontFile).data
		n.multichannel_signed_distance_field = true
		n.msdf_pixel_range = 16
		n.msdf_size = 64
		_sharp[key] = n
	return _sharp[key]


static func box(bg: Color, border: Color, bw := 2, radius := 6, bottom := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	if bottom > 0:
		s.border_width_bottom = bottom
	s.set_corner_radius_all(radius)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func metal_box(trim: Color, top := Color("3b4352"), bottom := Color("10131a"), glow := 0.5, pressed := 0.0) -> StyleBoxMetal:
	var b := StyleBoxMetal.new()
	b.trim = trim
	b.top = top
	b.bottom = bottom
	b.glow = glow
	b.pressed_offset = pressed
	b.content_margin_left = 34
	b.content_margin_right = 34
	b.content_margin_top = 10
	b.content_margin_bottom = 6
	return b


static func ink_box(fill: Color, accent := Color(0, 0, 0, 0), slant := 14.0, pressed := false, tone := true,
		frame := Color(0, 0, 0, 0)) -> StyleBoxInk:
	var b := StyleBoxInk.new()
	b.fill = fill
	b.accent = accent
	b.slant = slant
	b.pressed = pressed
	b.tone = tone
	b.frame = frame
	b.content_margin_left = 40
	b.content_margin_right = 40
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	return b


## The game-wide theme: manga panels and lettering to match the story pages (see Ink).
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = Ink.label_font()
	t.default_font_size = 32
	var letter := Ink.letter_font()
	# buttons: paper panels with an ink outline that sink into their shadow when pressed
	t.set_stylebox("normal", "Button", ink_box(Ink.PAPER))
	t.set_stylebox("hover", "Button", ink_box(Color("fff4c8"), Ink.RED))
	t.set_stylebox("pressed", "Button", ink_box(Ink.RED, Color(0, 0, 0, 0), 14.0, true))
	t.set_stylebox("hover_pressed", "Button", ink_box(Ink.RED, Color(0, 0, 0, 0), 14.0, true))
	t.set_stylebox("disabled", "Button", ink_box(Color("8a857a"), Color(0, 0, 0, 0), 14.0, false, false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Ink.INK)
	t.set_color("font_hover_color", "Button", Ink.INK)
	t.set_color("font_focus_color", "Button", Ink.INK)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.2, 0.2, 0.2, 0.6))
	t.set_font("font", "Button", letter)
	t.set_font_size("font_size", "Button", 50)
	# primary action: manga red with white lettering
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", ink_box(Ink.RED, Ink.GOLD))
	t.set_stylebox("hover", "PrimaryButton", ink_box(Color("ff4d55"), Ink.GOLD))
	t.set_stylebox("pressed", "PrimaryButton", ink_box(Color("a8202a"), Color(0, 0, 0, 0), 14.0, true))
	t.set_color("font_color", "PrimaryButton", Color.WHITE)
	t.set_color("font_hover_color", "PrimaryButton", Color.WHITE)
	t.set_color("font_pressed_color", "PrimaryButton", Color("ffe7a8"))
	t.set_color("font_outline_color", "PrimaryButton", Ink.INK)
	t.set_constant("outline_size", "PrimaryButton", 8)
	t.set_color("font_color", "Label", Color("f3eee2"))
	t.set_color("font_outline_color", "Label", Ink.INK)
	# panels: a night-page manga panel with a white inner frame
	var pbox := ink_box(Color(Ink.NIGHT, 0.97), Color(0, 0, 0, 0), 0.0, false, true, Color(1, 1, 1, 0.9))
	pbox.shadow = 12.0
	pbox.outline = 6.0
	pbox.content_margin_left = 54
	pbox.content_margin_right = 54
	pbox.content_margin_top = 38
	pbox.content_margin_bottom = 38
	t.set_stylebox("panel", "PanelContainer", pbox)
	# sliders: a paper track with an ink border, filled in red
	var track := box(Ink.PAPER_SHADE, Ink.INK, 4, 0)
	track.content_margin_top = 14
	track.content_margin_bottom = 14
	t.set_stylebox("slider", "HSlider", track)
	var ga := box(Ink.RED, Ink.INK, 4, 0)
	ga.content_margin_top = 14
	ga.content_margin_bottom = 14
	var gh := box(Color("ff4d55"), Ink.INK, 4, 0)
	gh.content_margin_top = 14
	gh.content_margin_bottom = 14
	t.set_stylebox("grabber_area", "HSlider", ga)
	t.set_stylebox("grabber_area_highlight", "HSlider", gh)
	t.set_icon("grabber", "HSlider", _grabber(false))
	t.set_icon("grabber_highlight", "HSlider", _grabber(true))
	# scrollbars (story log)
	t.set_stylebox("scroll", "VScrollBar", box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(Ink.PAPER, 0.5), Ink.INK, 2, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Ink.PAPER, Ink.INK, 2, 0))
	_theme = t
	return t


## Slider knob: a paper diamond with an ink outline (hover: red).
static func _grabber(hot: bool) -> Texture2D:
	var n := 44
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := absf(x - c) + absf(y - c)
			if d <= c - 1.0:
				img.set_pixel(x, y, Ink.INK if d > c - 6.0 else (Ink.RED if hot else Ink.PAPER))
	return ImageTexture.create_from_image(img)
