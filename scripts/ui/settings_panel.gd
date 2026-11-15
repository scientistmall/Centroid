class_name SettingsPanel
extends Control
## Settings overlay (main menu and pause menu): volumes, vibration, difficulty,
## touch-button size / opacity and left-handed layout. Saves on close.

signal closed


func _ready() -> void:
	add_to_group("back")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(InkBackdrop.new())
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1320, 0)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	vb.add_child(InkHeading.make("SETTINGS", 84))

	_slider(vb, "Music volume", Settings.music_volume, 0.0, 1.0, func(v): Settings.music_volume = v; AudioManager.apply_volumes())
	_slider(vb, "Effects volume", Settings.sfx_volume, 0.0, 1.0, func(v): Settings.sfx_volume = v; AudioManager.apply_volumes(); AudioManager.sfx("hit_light"))
	_slider(vb, "Button size", Settings.button_scale, 0.8, 1.3, func(v): Settings.button_scale = v)
	_slider(vb, "Button opacity", Settings.button_opacity, 0.4, 1.0, func(v): Settings.button_opacity = v)
	_toggle(vb, "Vibration", Settings.vibration, func(on): Settings.vibration = on)
	_toggle(vb, "Left-handed controls", Settings.left_handed, func(on): Settings.left_handed = on)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var lbl := Label.new()
	lbl.text = "Difficulty"
	lbl.custom_minimum_size.x = 380
	row.add_child(lbl)
	for i in 3:
		var b := Button.new()
		b.text = ["EASY", "NORMAL", "HARD"][i]
		b.toggle_mode = true
		b.button_pressed = Settings.difficulty == i
		b.custom_minimum_size = Vector2(200, 72)
		b.pressed.connect(func():
			Settings.difficulty = i
			for c in row.get_children():
				if c is Button:
					c.button_pressed = c.text == ["EASY", "NORMAL", "HARD"][i])
		row.add_child(b)

	var close := Button.new()
	close.text = "DONE"
	close.theme_type_variation = "PrimaryButton"
	close.custom_minimum_size = Vector2(320, 90)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	vb.add_child(close)


func _slider(parent: Control, text: String, value: float, lo: float, hi: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = 380
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.y = 60
	s.value_changed.connect(cb)
	row.add_child(s)


func _toggle(parent: Control, text: String, on: bool, cb: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = 380
	row.add_child(lbl)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.text = "ON" if on else "OFF"
	b.custom_minimum_size = Vector2(200, 72)
	b.toggled.connect(func(v):
		b.text = "ON" if v else "OFF"
		cb.call(v))
	row.add_child(b)


## Phone back button: close this overlay.
func on_back() -> bool:
	_close()
	return true


func _close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()
