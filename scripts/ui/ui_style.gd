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


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 36
	var teko: Font = load("res://assets/fonts/Teko-SemiBold.woff2")
	# heavy-metal buttons
	t.set_stylebox("normal", "Button", metal_box(Color("6fe3ff", 0.7)))
	t.set_stylebox("hover", "Button", metal_box(Color("aef1ff"), Color("4a5468"), Color("161b26"), 0.8))
	t.set_stylebox("pressed", "Button", metal_box(Color("f5c84c"), Color("2a3140"), Color("0b0d12"), 0.9, 2.0))
	t.set_stylebox("disabled", "Button", metal_box(Color(1, 1, 1, 0.15), Color("1e222b"), Color("0c0e12"), 0.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color("eaf6ff"))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("ffe08a"))
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_font("font", "Button", teko)
	t.set_font_size("font_size", "Button", 48)
	# gold primary buttons: theme_type_variation = "PrimaryButton"
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", metal_box(Color("fff0b0"), Color("ffe08a"), Color("b07a22"), 0.6))
	t.set_stylebox("hover", "PrimaryButton", metal_box(Color.WHITE, Color("fff0b0"), Color("c88e2c"), 0.9))
	t.set_stylebox("pressed", "PrimaryButton", metal_box(Color("fff0b0"), Color("d9a640"), Color("8a5a14"), 0.9, 2.0))
	t.set_color("font_color", "PrimaryButton", Color("1a1206"))
	t.set_color("font_hover_color", "PrimaryButton", Color("000000"))
	t.set_color("font_pressed_color", "PrimaryButton", Color("1a1206"))
	t.set_color("font_color", "Label", TEXT)
	var pbox := metal_box(Color("6fe3ff", 0.5), Color("262c38"), Color("0b0d12"), 0.4)
	pbox.cut = 26.0
	pbox.content_margin_left = 48
	pbox.content_margin_right = 48
	pbox.content_margin_top = 34
	pbox.content_margin_bottom = 34
	t.set_stylebox("panel", "PanelContainer", pbox)
	# sliders
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber_area", "HSlider", box(Color("6fe3ff", 0.75), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Color("aef1ff"), Color(0, 0, 0, 0), 0, 2))
	_theme = t
	return t
