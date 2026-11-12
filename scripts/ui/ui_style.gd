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


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 36
	t.set_stylebox("normal", "Button", box(Color(0.04, 0.05, 0.10, 0.82), Color(ACCENT, 0.35), 2, 4, 4))
	t.set_stylebox("hover", "Button", box(Color(0.07, 0.10, 0.18, 0.92), Color(ACCENT, 0.8), 2, 4, 4))
	t.set_stylebox("pressed", "Button", box(Color(0.12, 0.20, 0.32, 0.95), ACCENT, 2, 4, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", box(Color(0.03, 0.03, 0.05, 0.6), Color(1, 1, 1, 0.08), 2, 4, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT.lightened(0.4))
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_font("font", "Button", bold_font())
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(ACCENT, 0.3), 2, 10))
	# sliders / checkboxes for the settings screen
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT, 0.7), Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 0, 6))
	t.set_constant("grabber_offset", "HSlider", 0)
	_theme = t
	return t
