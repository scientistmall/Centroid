extends Control
## Full-colour manga story player.
##
## A scene is read as manga pages. Each `@page` is laid out from its panels' shapes (justified
## rows with gutters, slanted borders for action panels). Panels appear one at a time while a
## guided camera brings the active panel close; the lines after a panel appear in it as speech
## bubbles (pointing at the speaker's side of the panel) and narration captions, typed in.
## `@fx` letters a sound effect onto the panel. At the end of a page the camera pulls back to
## the whole page, then the page turns. Flashbacks get a warm, faded, grainy treatment.
## Panels without art yet show the backdrop and portraits instead, so every scene always plays.
##
## Tap / Enter advances; AUTO, LOG and SKIP buttons in the corner.

const TEXT_SPEED := 62.0          # characters per second
const CARD_MIN_TIME := 0.9
const GUTTER := 20.0
const MARGIN := Vector2(64, 44)
const PAPER := Color("07080c")
const INK := Color("050507")
const ASPECT := {"wide": 1.75, "action": 1.75, "square": 1.0, "tall": 0.68, "strip": 3.0, "splash": 2.25}
const SCREEN_FONT := 34.0         # dialogue size on screen when a panel is in focus (px)

const FLASHBACK_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;
void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 warm = vec3(g * 1.08, g * 0.93, g * 0.76);
	vec3 col = mix(c.rgb, warm, 0.72 * amount);
	float n = fract(sin(dot(SCREEN_UV * 900.0 + TIME * 13.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * 0.06 * amount;
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - dot(d, d) * 0.9 * amount;
	COLOR = vec4(col, 1.0);
}
"""

var scene_id := ""
var steps: Array = []
var next_dest: Dictionary = {"type": "menu"}
var index := -1

# test / router contract (same as the old player)
var _finished := false
var _blocked := false
var _waiting_card := false
var _card_elapsed := 0.0

var _cam: Control                 # moves / zooms the page
var _page: Control
var _panels: Dictionary = {}       # panel n -> PanelView on the current page
var _cur: PanelView
var _page_has_content := false
var _reviewed := false
var _bg_id := "black"
var _shown: Dictionary = {}        # slot -> char id (for panels without art)
var _flash_on := false
var _fb_overlay: ColorRect
var _memory_tag: Label
var _card: Control
var _card_lines: VBoxContainer
var _anim: Tween
var _typing: Bubble
var _hint: Label
var _auto := false
var _auto_btn: Button
var _wait_t := 0.0
var _log: Array = []
var _log_view: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_build_ui()
	scene_id = SceneRouter.current.get("id", "prologue")
	var data := StoryParser.load_file("res://data/story/%s.story" % scene_id)
	steps = data["steps"]
	next_dest = data["next"]
	_advance.call_deferred()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_cam = Control.new()
	_cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cam)
	_new_page()

	_memory_tag = Label.new()
	_memory_tag.text = "MEMORY"
	_memory_tag.position = Vector2(40, 26)
	_memory_tag.add_theme_font_override("font", UiStyle.title_font())
	_memory_tag.add_theme_font_size_override("font_size", 30)
	_memory_tag.add_theme_color_override("font_color", Color(1, 0.88, 0.68, 0.85))
	_memory_tag.visible = false
	add_child(_memory_tag)

	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.set_anchor(SIDE_LEFT, 1.0, true)
	_hint.set_anchor(SIDE_TOP, 1.0, true)
	_hint.position = Vector2(-70, -70)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_card = Control.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var cb := ColorRect.new()
	cb.color = Color("040406")
	cb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(cb)
	_card_lines = VBoxContainer.new()
	_card_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_lines.add_theme_constant_override("separation", 16)
	_card_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_lines)

	var bar := HBoxContainer.new()
	bar.set_anchor(SIDE_LEFT, 1.0, true)
	bar.set_anchor(SIDE_RIGHT, 1.0, true)
	bar.offset_left = -560
	bar.offset_right = -24
	bar.offset_top = 22
	bar.offset_bottom = 92
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	_auto_btn = _small_button("AUTO", func(): _auto = not _auto; _auto_btn.modulate = Color(1, 0.85, 0.4) if _auto else Color.WHITE)
	bar.add_child(_auto_btn)
	bar.add_child(_small_button("LOG", _open_log))
	bar.add_child(_small_button("SKIP ▶▶", _skip))


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 70)
	b.add_theme_font_size_override("font_size", 28)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _new_page() -> void:
	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.size = size if size != Vector2.ZERO else Vector2(2400, 1080)
	_cam.add_child(_page)
	_fb_overlay = ColorRect.new()
	_fb_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fb_overlay.size = _page.size
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLASHBACK_SHADER
	m.shader = sh
	_fb_overlay.material = m
	_fb_overlay.visible = _flash_on
	_page.add_child(_fb_overlay)
	_panels.clear()
	_cur = null
	_page_has_content = false
	_reviewed = false
	_cam.scale = Vector2.ONE
	_cam.position = Vector2.ZERO


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available()):
		if _log_view:
			_close_log()
		else:
			_on_tap()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance") or event.is_action_pressed("ui_accept"):
		_on_tap()


func _on_tap() -> void:
	if _finished or _blocked:
		return
	_wait_t = 0.0
	if _waiting_card:
		if _card_elapsed >= CARD_MIN_TIME:
			_close_card()
		return
	if _anim and _anim.is_valid() and _anim.is_running():
		_anim.custom_step(60.0)   # finish the running animation now
		return
	if _typing and not _typing.done():
		_typing.finish()
		return
	AudioManager.sfx("caption_tick", -14.0)
	_advance()


func _process(delta: float) -> void:
	if _waiting_card:
		_card_elapsed += delta
	var waiting := not _finished and not _waiting_card and not (_anim and _anim.is_valid() and _anim.is_running()) \
			and (_typing == null or _typing.done())
	_hint.visible = waiting and index >= 0
	_hint.modulate.a = 0.35 + 0.45 * absf(sin(Time.get_ticks_msec() / 320.0))
	if _auto and waiting and _log_view == null:
		_wait_t += delta
		var need := 1.4 + (0.028 * _typing.text.length() if _typing else 0.0)
		if _waiting_card:
			need = 2.6
		if _wait_t >= need:
			_on_tap()


# ---------------------------------------------------------------- steps

func _advance() -> void:
	while true:
		index += 1
		if index >= steps.size():
			_finish()
			return
		var s: Dictionary = steps[index]
		match s["t"]:
			"page":
				if _page_has_content and not _reviewed and _panels.size() > 1:
					# show the finished page whole before turning it
					index -= 1
					_reviewed = true
					_focus(Rect2(Vector2.ZERO, _page.size), 0.55)
					return
				if _page_has_content:
					_turn_page()
				_build_page(index + 1)
				if _anim and _anim.is_running():
					_anim.finished.connect(_advance, CONNECT_ONE_SHOT)
					return
			"panel":
				if _panels.is_empty():
					_build_page(index)
				_reveal(s)
				_anim.finished.connect(_advance, CONNECT_ONE_SHOT)
				return
			"line":
				_ensure_panel()
				_say(s)
				return
			"narrate":
				_ensure_panel()
				_caption(s["text"])
				return
			"fx":
				_ensure_panel()
				_fx(s)
			"card", "title":
				_open_card(s)
				return
			"bg":
				_bg_id = s["id"]
			"show":
				_shown[s["slot"]] = s["who"]
			"hide":
				if s["slot"] == "all":
					_shown.clear()
				else:
					_shown.erase(s["slot"])
			"flashback":
				_flash_on = s["on"]
				_fb_overlay.visible = _flash_on
				_memory_tag.visible = _flash_on
			"flag":
				StoryManager.set_flag(s["name"])
			"music":
				AudioManager.play_music(s["id"])
			"sfx":
				AudioManager.sfx(s["id"])
			"wait":
				_anim = create_tween()
				_anim.tween_interval(s["sec"])
				_anim.finished.connect(_advance, CONNECT_ONE_SHOT)
				return
			_:
				pass


## Lay out every panel of the page that starts at step `from` (until the next page/card/title).
func _build_page(from: int) -> void:
	var specs: Array = []
	for i in range(from, steps.size()):
		var t: String = steps[i]["t"]
		if t in ["page", "card", "title"]:
			break
		if t == "panel":
			specs.append(steps[i])
	if specs.is_empty():
		return
	var rects := _layout(specs)
	for k in specs.size():
		var sp: Dictionary = specs[k]
		var pv := PanelView.new()
		pv.setup(sp, rects[k], _bg_id, _shown.duplicate(), _flash_on)
		pv.modulate.a = 0.0
		_page.add_child(pv)
		_page.move_child(_fb_overlay, -1)
		_panels[sp["n"]] = pv


## Justified rows: try 1-3 rows over the panels in order, keep the arrangement that fills the
## page best.
func _layout(specs: Array) -> Array:
	var W := _page.size.x - MARGIN.x * 2.0
	var H := _page.size.y - MARGIN.y * 2.0
	var asp: Array = []
	for sp in specs:
		asp.append(float(ASPECT.get(sp["shape"], 1.75)))
	var n := asp.size()
	var best: Array = []
	var best_area := -1.0
	var splits := _partitions(n, mini(3, n))
	for rows in splits:
		var hs: Array = []
		var total := 0.0
		var start := 0
		for cnt in rows:
			var sum_a := 0.0
			for j in range(start, start + cnt):
				sum_a += asp[j]
			var h: float = (W - GUTTER * (cnt - 1)) / sum_a
			hs.append(h)
			total += h
			start += cnt
		total += GUTTER * (rows.size() - 1)
		var s: float = minf(1.0, H / total)
		var area := 0.0
		for h in hs:
			area += h * s * W * s
		# prefer layouts that use the page height and keep panels from getting too thin
		var min_h: float = hs.min() * s
		if min_h < H * 0.22:
			area *= 0.6
		if area > best_area:
			best_area = area
			best = [rows, hs, s, total]
	var rows_b: Array = best[0]
	var hs_b: Array = best[1]
	var sc: float = best[2]
	var used_h: float = best[3] * sc
	var y := MARGIN.y + (H - used_h) / 2.0
	var out: Array = []
	var idx := 0
	for r in rows_b.size():
		var cnt: int = rows_b[r]
		var h: float = hs_b[r] * sc
		var row_w := 0.0
		for j in range(idx, idx + cnt):
			row_w += asp[j] * h
		row_w += GUTTER * (cnt - 1)
		var x := MARGIN.x + (W - row_w) / 2.0
		for j in range(idx, idx + cnt):
			var w: float = asp[j] * h
			out.append(Rect2(x, y, w, h))
			x += w + GUTTER
		y += h + GUTTER
		idx += cnt
	return out


## All ways to split n panels (in order) into 1..max_rows non-empty rows.
static func _partitions(n: int, max_rows: int) -> Array:
	var res: Array = []
	for r in range(1, max_rows + 1):
		_part_rec(n, r, [], res)
	return res


static func _part_rec(left: int, rows: int, acc: Array, res: Array) -> void:
	if rows == 1:
		if left >= 1:
			res.append(acc + [left])
		return
	for k in range(1, left - rows + 2):
		_part_rec(left - k, rows - 1, acc + [k], res)


## A line or caption with no panel yet: give it a panel built from the current backdrop.
func _ensure_panel() -> void:
	if _cur != null:
		return
	if _page_has_content:
		_turn_page()
	var sp := {"t": "panel", "n": -1, "scene": scene_id, "shape": "splash", "cast": _shown.values(), "dir": ""}
	var pv := PanelView.new()
	pv.setup(sp, Rect2(MARGIN, _page.size - MARGIN * 2.0), _bg_id, _shown.duplicate(), _flash_on)
	_page.add_child(pv)
	_page.move_child(_fb_overlay, -1)
	_panels[-1] = pv
	_cur = pv
	_page_has_content = true


func _reveal(s: Dictionary) -> void:
	var pv: PanelView = _panels.get(s["n"])
	if pv == null:
		_build_page(index)
		pv = _panels.get(s["n"])
	if _cur:
		_cur.dim(true)
	_cur = pv
	_page_has_content = true
	_reviewed = false
	pv.bg_id = _bg_id
	AudioManager.sfx("panel_in", -6.0)
	var z := _focus(pv.rect, 0.5)
	pv.font_px = SCREEN_FONT / z
	pv.reveal()
	_anim.parallel().tween_property(pv, "modulate:a", 1.0, 0.35)
	_anim.parallel().tween_property(pv, "position", pv.rect.position, 0.45).from(pv.rect.position + Vector2(36, 0)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Move the camera so `r` (page coordinates) fills the screen. Returns the zoom.
func _focus(r: Rect2, time: float) -> float:
	var vs := size
	var z := clampf(minf(vs.x * 0.92 / r.size.x, vs.y * 0.86 / r.size.y), 1.0, 1.9)
	var pos := vs / 2.0 - (r.position + r.size / 2.0) * z
	pos.x = clampf(pos.x, vs.x - _page.size.x * z, 0.0)
	pos.y = clampf(pos.y, vs.y - _page.size.y * z, 0.0)
	_anim = create_tween().set_parallel(true)
	_anim.tween_property(_cam, "scale", Vector2(z, z), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_anim.tween_property(_cam, "position", pos, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return z


func _turn_page() -> void:
	AudioManager.sfx("page_turn", -2.0)
	var old := _page
	var old_scale := _cam.scale
	var old_pos := _cam.position
	# keep the old page where it is on screen while it flips away
	old.reparent(self)
	old.scale = old_scale
	old.position = old_pos
	old.z_index = 2
	var t := create_tween().set_parallel(true)
	t.tween_property(old, "position:x", old.position.x - size.x * 1.15, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(old, "rotation", -0.06, 0.5)
	t.tween_property(old, "modulate", Color(0.6, 0.6, 0.65, 0.0), 0.5)
	t.chain().tween_callback(old.queue_free)
	_new_page()
	_page.modulate.a = 0.0
	_anim = create_tween()
	_anim.tween_property(_page, "modulate:a", 1.0, 0.35).set_delay(0.12)


func _say(s: Dictionary) -> void:
	var who: String = s["who"]
	var info := StoryParser.character(who)
	var col := Color(info.get("color", "#ffffff"))
	var expr: String = s.get("expr", "")
	var style := "round"
	if expr in ["angry", "shocked"]:
		style = "burst"
	if info.get("hair", "") == "none":
		style = "voice"
	_log.append([s["name"], s["text"], col])
	_typing = _cur.add_bubble(s["text"], s["name"], col, style, who)
	AudioManager.sfx("bubble", -10.0, 0.12)


func _caption(text: String) -> void:
	_log.append(["", text, Color(0.75, 0.76, 0.82)])
	_typing = _cur.add_bubble(text, "", Color.WHITE, "caption", "")


func _fx(s: Dictionary) -> void:
	_cur.add_fx(s["text"])
	AudioManager.sfx(s["sound"] if s["sound"] != "" else "hit_heavy", 0.0)
	var t := create_tween()
	var base := _cam.position
	for i in 6:
		t.tween_property(_cam, "position", base + Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.03)
	t.tween_property(_cam, "position", base, 0.04)


func _open_card(s: Dictionary) -> void:
	for c in _card_lines.get_children():
		c.queue_free()
	var lines: Array = s["lines"]
	for i in lines.size():
		var l := Label.new()
		l.text = String(lines[i]).to_upper() if i == 0 else String(lines[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var big: bool = s["t"] == "title" and i == 0
		l.add_theme_font_override("font", UiStyle.title_font() if i == 0 else UiStyle.ui_font())
		l.add_theme_font_size_override("font_size", 120 if big else (64 if i == 0 else 38))
		l.add_theme_color_override("font_color", Color(1, 0.86, 0.6) if i == 0 else Color(0.72, 0.74, 0.82))
		l.add_theme_constant_override("outline_size", 0)
		_card_lines.add_child(l)
		if i == 0:
			var rule := ColorRect.new()
			rule.color = Color(1, 0.8, 0.45, 0.6)
			rule.custom_minimum_size = Vector2(420, 3)
			rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_card_lines.add_child(rule)
	_card.visible = true
	_card.modulate.a = 0.0
	_waiting_card = true
	_card_elapsed = 0.0
	AudioManager.sfx("page_turn", -6.0)
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.5)


func _close_card() -> void:
	_waiting_card = false
	_blocked = true
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 0.0, 0.35)
	await t.finished
	_card.visible = false
	_blocked = false
	if _page_has_content:
		_turn_page()
	_advance()


func _open_log() -> void:
	if _log_view:
		return
	_log_view = PanelContainer.new()
	_log_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.04, 0.94)
	sb.content_margin_left = 120
	sb.content_margin_right = 120
	sb.content_margin_top = 110
	sb.content_margin_bottom = 60
	_log_view.add_theme_stylebox_override("panel", sb)
	var sc := ScrollContainer.new()
	_log_view.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	sc.add_child(vb)
	for e in _log.slice(maxi(0, _log.size() - 120)):
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.add_theme_font_size_override("normal_font_size", 32)
		var col: Color = e[2]
		if e[0] == "":
			r.text = "[i][color=#aeb3c6]%s[/color][/i]" % e[1]
		else:
			r.text = "[color=#%s][b]%s[/b][/color]   %s" % [col.to_html(false), e[0], e[1]]
		vb.add_child(r)
	add_child(_log_view)
	sc.scroll_vertical = 1 << 20


func _close_log() -> void:
	_log_view.queue_free()
	_log_view = null


func _skip() -> void:
	if _finished:
		return
	for i in range(index + 1, steps.size()):
		if steps[i]["t"] == "flag":
			StoryManager.set_flag(steps[i]["name"])
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	SceneRouter.go(next_dest)


# ======================================================================= panel

class PanelView extends Control:
	## One manga panel: its art (or backdrop + portraits until the art exists), border, a slow
	## drift on the art, and the bubbles / captions / effect lettering placed in it.
	var spec: Dictionary
	var rect: Rect2
	var bg_id := "black"
	var font_px := 34.0
	var _art: Control
	var _drift := 0.0
	var _cursor := {}      # column -> next free y for bubbles
	var _items: Array = []
	var _dim := false

	func setup(sp: Dictionary, r: Rect2, bg: String, shown: Dictionary, flash: bool) -> void:
		spec = sp
		rect = r
		bg_id = bg
		position = r.position
		size = r.size
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path := StoryParser.panel_art(sp.get("scene", ""), int(sp.get("n", -1)))
		if int(sp.get("n", -1)) > 0 and ResourceLoader.exists(path):
			var tr := TextureRect.new()
			tr.texture = load(path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.size = r.size
			tr.pivot_offset = r.size / 2.0
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_art = tr
			add_child(tr)
		else:
			_art = Control.new()
			_art.size = r.size
			_art.pivot_offset = r.size / 2.0
			_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_art)
			var b := Backdrop.new()
			b.bg_id = bg
			b.size = r.size
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_art.add_child(b)
			var cast: Array = sp.get("cast", [])
			if cast.is_empty():
				cast = shown.values()
			for i in cast.size():
				var p := Portrait.new()
				p.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var w := r.size.x / maxf(2.0, cast.size())
				p.size = Vector2(minf(w, r.size.y * 0.8), r.size.y * 0.82)
				p.position = Vector2((i + 0.5) * r.size.x / cast.size() - p.size.x / 2.0, r.size.y * 0.18)
				_art.add_child(p)
				p.set_character(cast[i], i > 0 and i == cast.size() - 1)
		var border := _Border.new()
		border.panel = self
		border.size = r.size
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(border)

	func reveal() -> void:
		_drift = 0.0

	func dim(on: bool) -> void:
		_dim = on
		for it in _items:
			if it is Bubble:
				(it as Bubble).modulate.a = 0.55 if on else 1.0

	func _process(delta: float) -> void:
		# slow push-in on the art (ken burns), stronger on splash / action panels
		_drift = minf(_drift + delta, 12.0)
		var amt := 0.07 if spec.get("shape", "") in ["splash", "action"] else 0.045
		var k := ease(_drift / 12.0, -1.6)
		if _art:
			_art.scale = Vector2.ONE * (1.0 + amt * k)

	func slanted() -> bool:
		return spec.get("shape", "") == "action"

	## Where a speaker stands in this panel (x fraction), or -1 if not in the cast.
	func speaker_x(who: String) -> float:
		var cast: Array = spec.get("cast", [])
		var i := cast.find(who)
		if i == -1:
			return -1.0
		return (i + 0.5) / cast.size()

	func add_bubble(text: String, speaker: String, col: Color, style: String, who: String) -> Bubble:
		var b := Bubble.new()
		var pad := rect.size.x * 0.035
		var max_w := rect.size.x * (0.86 if style == "caption" else 0.46)
		b.build(text, speaker, col, style, font_px, max_w)
		var sx := speaker_x(who)
		var col_key := "c"
		var x: float
		if style == "caption":
			x = pad
			col_key = "l"
		elif sx < 0.0:
			x = rect.size.x - b.size.x - pad      # off-panel speaker: right edge
			col_key = "r"
		else:
			x = clampf(sx * rect.size.x - b.size.x / 2.0, pad, rect.size.x - b.size.x - pad)
			col_key = "l" if sx < 0.5 else "r"
		# one reading order: every bubble / caption stacks below the previous one
		col_key = "all"
		var y: float = _cursor.get(col_key, pad + (font_px * 0.6 if speaker != "" else 0.0))
		if speaker != "" and _cursor.has(col_key):
			y += font_px * 0.6   # room for the name tag
		if y + b.size.y > rect.size.y * 0.66 and not _items.is_empty():
			# full: clear older bubbles so the panel stays readable
			for it in _items:
				var node: Control = it
				var t: Tween = node.create_tween()
				t.tween_property(node, "modulate:a", 0.0, 0.2)
				t.tween_callback(node.queue_free)
			_items.clear()
			_cursor.clear()
			y = pad + (font_px * 0.6 if speaker != "" else 0.0)
		b.position = Vector2(x, y)
		if style != "caption":
			var cast_n: int = (spec.get("cast", []) as Array).size()
			if sx < 0.0:
				b.tail_to = Vector2(rect.size.x + 40.0, y + b.size.y * 1.4) - b.position
			elif cast_n <= 1:
				# one character in the panel: a short tail straight down (their position in the art is unknown)
				b.tail_to = Vector2(b.size.x * 0.5, b.size.y + font_px * 2.2)
			else:
				b.tail_to = Vector2(sx * rect.size.x, rect.size.y * 0.42) - b.position
		_cursor[col_key] = y + b.size.y + font_px * 0.45
		add_child(b)
		move_child(b, -2)   # under the border
		_items.append(b)
		b.scale = Vector2(0.85, 0.85)
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return b

	func add_fx(text: String) -> void:
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", UiStyle.title_font())
		l.add_theme_font_size_override("font_size", int(font_px * 3.6))
		l.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
		l.add_theme_constant_override("outline_size", int(font_px * 0.55))
		l.add_theme_color_override("font_shadow_color", Color(0.85, 0.15, 0.1, 0.8))
		l.add_theme_constant_override("shadow_offset_x", int(font_px * 0.18))
		l.add_theme_constant_override("shadow_offset_y", int(font_px * 0.18))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		move_child(l, -2)
		await get_tree().process_frame
		l.pivot_offset = l.size / 2.0
		l.position = Vector2(rect.size.x * randf_range(0.42, 0.58), rect.size.y * randf_range(0.42, 0.6)) - l.size / 2.0
		l.rotation = deg_to_rad(randf_range(-12.0, 12.0))
		l.scale = Vector2(1.8, 1.8)
		l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_items.append(l)


class _Border extends Control:
	var panel: PanelView

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var paper := Color("07080c")
		var ink := Color("f2efe8")
		if panel.slanted():
			# a dynamic slanted frame for action panels: cut the corners with paper
			var cut := h * 0.12
			draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(cut, 0), Vector2(0, h)]), paper)
			draw_colored_polygon(PackedVector2Array([Vector2(w, h), Vector2(w - cut, h), Vector2(w, 0)]), paper)
			draw_polyline(PackedVector2Array([Vector2(cut, 0), Vector2(w, 0), Vector2(w - cut, h), Vector2(0, h), Vector2(cut, 0)]), ink, 5.0, true)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), ink, false, 5.0)
			draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), Color(0, 0, 0, 0.55), false, 3.0)


# ======================================================================= bubble

class Bubble extends Control:
	## A speech bubble / burst / caption with its own typewriter.
	var text := ""
	var speaker := ""
	var color := Color.WHITE
	var style := "round"
	var tail_to := Vector2.ZERO
	var _fs := 34.0
	var _font: Font
	var _lines: PackedStringArray = []
	var _vis := 0.0
	var _pad := Vector2.ZERO

	func build(t: String, who: String, col: Color, st: String, font_px: float, max_w: float) -> void:
		text = t
		speaker = who
		color = col
		style = st
		_fs = font_px
		_font = UiStyle.ui_font() if st == "caption" else UiStyle.bold_font()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pad = Vector2(font_px * 1.0, font_px * 0.62) if st != "caption" else Vector2(font_px * 0.7, font_px * 0.5)
		if st == "burst":
			_pad *= 1.35
		_lines = _wrap(t, max_w - _pad.x * 2.0)
		var lw := 0.0
		for l in _lines:
			lw = maxf(lw, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_fs)).x)
		var lh := _font.get_height(int(_fs)) * 1.08
		size = Vector2(lw + _pad.x * 2.0, lh * _lines.size() + _pad.y * 2.0)

	func _wrap(t: String, w: float) -> PackedStringArray:
		var out := PackedStringArray()
		var cur := ""
		for word in t.split(" ", false):
			var trial := word if cur == "" else cur + " " + word
			if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_fs)).x > w and cur != "":
				out.append(cur)
				cur = word
			else:
				cur = trial
		if cur != "":
			out.append(cur)
		return out

	func done() -> bool:
		return _vis >= text.length()

	func finish() -> void:
		_vis = text.length()
		queue_redraw()

	func _process(delta: float) -> void:
		if _vis < text.length():
			_vis = minf(text.length(), _vis + 62.0 * delta)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var ink := Color(0.03, 0.03, 0.05)
		if style == "caption":
			draw_rect(r, Color(0.06, 0.07, 0.1, 0.94))
			draw_rect(r, Color(0.92, 0.78, 0.5, 0.9), false, maxf(2.0, _fs * 0.08))
		elif style == "burst":
			var pts := PackedVector2Array()
			var c := r.get_center()
			var n := 22
			for i in n:
				var a := TAU * i / n
				var k := 1.0 if i % 2 == 0 else 0.84
				pts.append(c + Vector2(cos(a) * r.size.x * 0.56 * k, sin(a) * r.size.y * 0.62 * k))
			_tail(c, ink, Color.WHITE)
			draw_colored_polygon(pts, Color.WHITE)
			pts.append(pts[0])
			draw_polyline(pts, ink, maxf(3.0, _fs * 0.12), true)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.98, 0.97, 1.0) if style != "voice" else Color(0.12, 0.06, 0.2)
			sb.border_color = ink if style != "voice" else Color(0.78, 0.6, 1.0)
			sb.set_border_width_all(int(maxf(3.0, _fs * 0.11)))
			sb.set_corner_radius_all(int(minf(r.size.y * 0.5, _fs * 1.6)))
			sb.anti_aliasing = true
			_tail(r.get_center(), sb.border_color, sb.bg_color)
			draw_style_box(sb, r)
		# speaker tag
		if speaker != "":
			var tag_fs := int(_fs * 0.62)
			var tag_w := _font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_fs).x + _fs * 0.6
			var tag := Rect2(Vector2(_fs * 0.5, -tag_fs * 1.05), Vector2(tag_w, tag_fs * 1.25))
			draw_rect(tag, color.darkened(0.55))
			draw_string(_font, tag.position + Vector2(_fs * 0.3, tag_fs * 0.98), speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_fs, color.lightened(0.35))
		# text (typewriter)
		var lh := _font.get_height(int(_fs)) * 1.08
		var left := int(_vis)
		var col := ink if style in ["round", "burst"] else (Color(0.92, 0.9, 0.86) if style == "caption" else Color(0.86, 0.75, 1.0))
		for i in _lines.size():
			if left <= 0:
				break
			var line: String = _lines[i]
			var shown := line.substr(0, left)
			left -= line.length() + 1
			var lw := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_fs)).x
			var x := (size.x - lw) / 2.0 if style != "caption" else _pad.x
			draw_string(_font, Vector2(x, _pad.y + lh * i + _font.get_ascent(int(_fs))), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_fs), col)

	func _tail(c: Vector2, edge: Color, fill: Color) -> void:
		if tail_to == Vector2.ZERO:
			return
		var dir := (tail_to - c).normalized()
		var side := Vector2(-dir.y, dir.x) * _fs * 0.55
		var base := c + dir * minf(size.x, size.y) * 0.35
		var tip := c + (tail_to - c).limit_length(maxf(size.y * 1.1, _fs * 2.6))
		draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), fill)
		draw_line(base + side, tip, edge, maxf(3.0, _fs * 0.11), true)
		draw_line(base - side, tip, edge, maxf(3.0, _fs * 0.11), true)
