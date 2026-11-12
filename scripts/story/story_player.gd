extends Control
## Visual-novel style scene player: backdrop, two portrait slots, text box,
## title cards and a flashback tint. Tap (or Enter) to advance.

const TEXT_SPEED := 55.0          # characters per second
const CARD_MIN_TIME := 1.0        # seconds before a card can be tapped away

const FLASHBACK_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;
void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(g * 1.07, g * 0.92, g * 0.74);
	COLOR = vec4(mix(c.rgb, sepia, amount), 1.0);
}
"""

var scene_id := ""
var steps: Array = []
var next_dest: Dictionary = {"type": "menu"}
var index := -1

var _backdrop: Backdrop
var _portraits := {}            # "left"/"right" -> Portrait
var _last_spoke := {"left": -1, "right": -1}
var _flashback: ColorRect
var _flash_label: Label
var _box: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _card: ColorRect
var _card_box: VBoxContainer
var _tap_hint: Label

var _typing := false
var _waiting_card := false
var _card_elapsed := 0.0
var _blocked := false
var _finished := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	scene_id = SceneRouter.current.get("id", "prologue")
	var data := StoryParser.load_file("res://data/story/%s.story" % scene_id)
	steps = data["steps"]
	next_dest = data["next"]
	_advance()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	for slot in ["left", "right"]:
		var p := Portrait.new()
		p.set_anchor(SIDE_TOP, 0.16, true)
		p.set_anchor(SIDE_BOTTOM, 0.72, true)
		if slot == "left":
			p.set_anchor(SIDE_LEFT, 0.06, true)
			p.set_anchor(SIDE_RIGHT, 0.30, true)
		else:
			p.set_anchor(SIDE_LEFT, 0.70, true)
			p.set_anchor(SIDE_RIGHT, 0.94, true)
		p.visible = false
		add_child(p)
		_portraits[slot] = p

	_flashback = ColorRect.new()
	_flashback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flashback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLASHBACK_SHADER
	mat.shader = sh
	_flashback.material = mat
	_flashback.visible = false
	add_child(_flashback)

	_flash_label = Label.new()
	_flash_label.text = "— MEMORY —"
	_flash_label.position = Vector2(48, 36)
	_flash_label.add_theme_font_size_override("font_size", 30)
	_flash_label.add_theme_color_override("font_color", Color(1, 0.92, 0.75, 0.8))
	_flash_label.visible = false
	add_child(_flash_label)

	_box = PanelContainer.new()
	_box.set_anchor(SIDE_LEFT, 0.05, true)
	_box.set_anchor(SIDE_RIGHT, 0.95, true)
	_box.set_anchor(SIDE_TOP, 0.68, true)
	_box.set_anchor(SIDE_BOTTOM, 0.96, true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.05, 0.86)
	sb.border_color = Color(0.4, 0.8, 1.0, 0.7)
	sb.border_width_top = 3
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	_box.add_theme_stylebox_override("panel", sb)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(vb)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 40)
	vb.add_child(_name_label)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 40)
	_text.add_theme_font_size_override("italics_font_size", 38)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_text)

	_tap_hint = Label.new()
	_tap_hint.text = "▼"
	_tap_hint.set_anchor(SIDE_LEFT, 0.93, true)
	_tap_hint.set_anchor(SIDE_TOP, 0.9, true)
	_tap_hint.add_theme_font_size_override("font_size", 30)
	_tap_hint.modulate = Color(1, 1, 1, 0.7)
	add_child(_tap_hint)

	_card = ColorRect.new()
	_card.color = Color.BLACK
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	_card_box = VBoxContainer.new()
	_card_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_box.add_theme_constant_override("separation", 18)
	_card.add_child(_card_box)

	var skip := Button.new()
	skip.text = "SKIP ▶▶"
	skip.set_anchor(SIDE_LEFT, 1.0, true)
	skip.set_anchor(SIDE_RIGHT, 1.0, true)
	skip.offset_left = -230
	skip.offset_right = -30
	skip.offset_top = 30
	skip.offset_bottom = 100
	skip.add_theme_font_size_override("font_size", 30)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_skip)
	add_child(skip)


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available()):
		_on_tap()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance") or event.is_action_pressed("ui_accept"):
		_on_tap()


func _on_tap() -> void:
	if _finished or _blocked:
		return
	if _waiting_card:
		if _card_elapsed >= CARD_MIN_TIME:
			_close_card()
		return
	if _typing:
		_text.visible_ratio = 1.0
		_typing = false
		return
	_advance()


func _process(delta: float) -> void:
	if _typing:
		var total := _text.get_total_character_count()
		if total <= 0:
			_typing = false
		else:
			_text.visible_characters = mini(total, _text.visible_characters + maxi(1, int(ceil(TEXT_SPEED * delta))))
			if _text.visible_characters >= total:
				_typing = false
	if _waiting_card:
		_card_elapsed += delta
	_tap_hint.visible = not _typing and not _waiting_card and _box.visible
	_tap_hint.modulate.a = 0.4 + 0.4 * absf(sin(Time.get_ticks_msec() / 300.0))


# ---------------------------------------------------------------- steps

func _advance() -> void:
	while true:
		index += 1
		if index >= steps.size():
			_finish()
			return
		var s: Dictionary = steps[index]
		match s["t"]:
			"bg":
				_backdrop.bg_id = s["id"]
			"show":
				_show(s["slot"], s["who"])
			"hide":
				_hide(s["slot"])
			"flashback":
				_flashback.visible = s["on"]
				_flash_label.visible = s["on"]
			"flag":
				StoryManager.set_flag(s["name"])
			"music":
				AudioManager.play_music(s["id"])
			"sfx":
				AudioManager.sfx(s["id"])
			"line":
				_say(s)
				return
			"narrate":
				_narrate(s["text"])
				return
			"card", "title":
				_open_card(s)
				return
			"wait":
				_blocked = true
				_box.visible = false
				await get_tree().create_timer(s["sec"]).timeout
				_blocked = false
				# continue to the next step automatically
			_:
				pass


func _show(slot: String, who: String) -> void:
	if not _portraits.has(slot):
		return
	var p: Portrait = _portraits[slot]
	p.set_character(who, slot == "right")
	p.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(p, "modulate:a", 1.0, 0.25)


func _hide(slot: String) -> void:
	for k in _portraits:
		if slot == "all" or slot == k:
			_portraits[k].char_id = ""
			_portraits[k].visible = false


func _slot_of(who: String) -> String:
	for k in _portraits:
		if _portraits[k].visible and _portraits[k].char_id == who:
			return k
	return ""


func _say(s: Dictionary) -> void:
	var who: String = s["who"]
	var info := StoryParser.character(who)
	var col := Color(info.get("color", "#ffffff"))
	var is_voice: bool = info.get("hair", "") == "none"
	if not is_voice:
		var slot := _slot_of(who)
		if slot == "":
			# Put the new speaker in the free slot, or replace whoever spoke least recently.
			if not _portraits["left"].visible:
				slot = "left"
			elif not _portraits["right"].visible:
				slot = "right"
			else:
				slot = "left" if _last_spoke["left"] < _last_spoke["right"] else "right"
			_show(slot, who)
		_last_spoke[slot] = index
		_portraits[slot].set_expression(s.get("expr", ""))
		for k in _portraits:
			_portraits[k].self_modulate = Color.WHITE if k == slot else Color(0.45, 0.45, 0.5)
	_box.visible = true
	_name_label.visible = true
	_name_label.text = s["name"]
	_name_label.add_theme_color_override("font_color", col)
	(_box.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(col, 0.8)
	var body: String = s["text"]
	if is_voice:
		body = "[color=#c9a8ff][wave amp=18 freq=3]%s[/wave][/color]" % body
	_start_text(body)


func _narrate(text: String) -> void:
	_box.visible = true
	_name_label.visible = false
	(_box.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(1, 1, 1, 0.25)
	for k in _portraits:
		_portraits[k].self_modulate = Color(0.75, 0.75, 0.8)
	_start_text("[i][color=#bfc3d6]%s[/color][/i]" % text)


func _start_text(bb: String) -> void:
	_text.text = bb
	_text.visible_characters = 0
	_typing = true


func _open_card(s: Dictionary) -> void:
	for c in _card_box.get_children():
		c.queue_free()
	var lines: Array = s["lines"]
	for i in lines.size():
		var l := Label.new()
		l.text = lines[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var big: bool = s["t"] == "title" and i == 0
		var first: bool = i == 0
		l.add_theme_font_size_override("font_size", 110 if big else (56 if first else 36))
		l.add_theme_color_override("font_color", Color(1, 0.9, 0.7) if big else (Color.WHITE if first else Color(0.7, 0.72, 0.8)))
		_card_box.add_child(l)
	_card.visible = true
	_card.modulate.a = 0.0
	_box.visible = false
	_waiting_card = true
	_card_elapsed = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.5)


func _close_card() -> void:
	_waiting_card = false
	_blocked = true
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 0.0, 0.4)
	await t.finished
	_card.visible = false
	_blocked = false
	_advance()


func _skip() -> void:
	if _finished:
		return
	# Apply any flags in the rest of the scene so skipping never loses progress.
	for i in range(index + 1, steps.size()):
		if steps[i]["t"] == "flag":
			StoryManager.set_flag(steps[i]["name"])
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_typing = false
	SceneRouter.go(next_dest)
