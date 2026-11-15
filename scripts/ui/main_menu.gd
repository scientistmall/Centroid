extends Control
## Title screen. The first time the game opens: the living key-art wallpaper (TitleWallpaper) and
## the Centroid loading ring while the heavy fight assets load in the background, then
## "TAP TO START" and the menu slides up over the same wallpaper. Coming back to the menu later
## skips the loading.

## Loaded once at boot and kept referenced, so fights open without a hitch.
const PRELOAD := [
	"res://assets/animations/centroid_anims.res",
	"res://assets/characters/kael/kael.tscn", "res://assets/characters/rhex/rhex.tscn",
	"res://assets/characters/mira/mira.tscn", "res://assets/characters/tala/tala.tscn",
	"res://assets/weapons/kael_sword.glb", "res://assets/weapons/rhex_axe.glb",
	"res://assets/weapons/mira_blade.glb", "res://assets/weapons/tala_spear.glb",
	"res://scenes/story/story_player.tscn", "res://scenes/fight/arena.tscn",
]
const MIN_BOOT := 2.4   # the ring always gets a moment on screen, even on a fast phone

static var _booted := false
static var _keep: Array = []

var _confirm: Control
var _t := 0.0
var _ring: LoadingRing
var _pending: Array[String] = []
var _menu: Control
var _wall: TitleWallpaper


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("main_theme")
	_wall = TitleWallpaper.new()
	add_child(_wall)
	add_child(_Logo.new())
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	_build_menu()
	if _booted:
		return
	_menu.visible = false
	_ring = LoadingRing.new()
	add_child(_ring)
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.start_pressed.connect(_enter)
	_wall.centroid_shown = 0.0
	for path in PRELOAD:
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path, "", true) == OK:
			_pending.append(path)


func _process(delta: float) -> void:
	_t += delta
	if _ring != null and is_instance_valid(_ring):
		_ring.centre_frac = _wall.centroid_at
		# the crystal lands on the altar: hand over to the wallpaper's Centroid
		if _ring._settle >= 1.0:
			_wall.centroid_shown = minf(1.0, _wall.centroid_shown + delta * 3.0)
	if _ring == null or _ring.done:
		return
	var total := 0.0
	var all_done := true
	for path in _pending:
		var prog := []
		var st := ResourceLoader.load_threaded_get_status(path, prog)
		match st:
			ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				total += 1.0
			_:
				total += float(prog[0]) if prog.size() > 0 else 0.0
				all_done = false
	var frac := total / maxf(1.0, _pending.size())
	_ring.progress = minf(frac, _t / MIN_BOOT)
	if all_done and _t >= MIN_BOOT:
		for path in _pending:
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
				_keep.append(ResourceLoader.load_threaded_get(path))
		_ring.finish()


## Tap to start: the ring fades and the menu rises over the wallpaper.
func _enter() -> void:
	_booted = true
	_wall.centroid_shown = 1.0
	AudioManager.sfx("panel_in", -6.0)
	var tw := create_tween()
	tw.tween_property(_ring, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_ring.queue_free)
	_menu.visible = true
	_menu.modulate.a = 0.0
	_menu.position.y = 60.0
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(_menu, "modulate:a", 1.0, 0.45)
	tw2.tween_property(_menu, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_menu() -> void:
	# one row of big metal buttons along the bottom, so the whole wallpaper stays in view
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchor(SIDE_LEFT, 0.04, true)
	row.set_anchor(SIDE_RIGHT, 0.96, true)
	row.set_anchor(SIDE_TOP, 0.86, true)
	row.set_anchor(SIDE_BOTTOM, 0.97, true)
	row.add_theme_constant_override("separation", 24)
	_menu.add_child(row)
	if StoryManager.has_save():
		_add(row, "CONTINUE", func(): SceneRouter.go(StoryManager.resume_point), true)
		_add(row, "NEW GAME", _new_game)
	else:
		_add(row, "START STORY", _new_game, true)
	_add(row, "CHAPTERS", func(): SceneRouter.go({"type": "chapters"}))
	_add(row, "SETTINGS", func(): add_child(SettingsPanel.new()))
	var plaque := _Plaque.new()
	_menu.add_child(plaque)
	plaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _add(parent: Control, text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 104)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 52 if primary else 44)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _new_game() -> void:
	if not StoryManager.has_save():
		_start_new()
		return
	_confirm = _Dialog.new()
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


## A modal dialog the phone's back button closes.
class _Dialog extends Control:
	func _ready() -> void:
		add_to_group("back")

	func on_back() -> bool:
		queue_free()
		return true


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
		var tf := UiStyle.title_font()
		var fs := int(h * 0.1)
		var glow := 0.5 + 0.2 * sin(t * 1.3)
		var p := Vector2(0, h * 0.13)
		var w := size.x
		draw_string_outline(tf, p, "THE CENTROID", HORIZONTAL_ALIGNMENT_CENTER, w, fs, 26, Color(0.55, 0.42, 1.0, 0.18 * glow))
		draw_string_outline(tf, p, "THE CENTROID", HORIZONTAL_ALIGNMENT_CENTER, w, fs, 10, Color(0, 0, 0, 0.9))
		draw_string(tf, p, "THE CENTROID", HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0.95, 0.96, 1.0))
		Metal.shout(self, Vector2(w * 0.5, h * 0.195), "37 DAYS OF DARKNESS  ·  PART ONE", int(h * 0.036), Metal.GOLD, Metal.GOLD, true)


## Progress plaque, top right.
class _Plaque extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := Rect2(w - 620, 28, 590, 92)
		Metal.panel(self, r, Metal.GOLD, 20.0, Color("2a303c"), Color("0b0d12"), 0.5)
		var done := StoryManager.chapters_done()
		var day := StoryManager.days_reached()
		Metal.shout(self, Vector2(r.position.x + 30, r.position.y + 70), "DAY %d / %d" % [day, StoryManager.TOTAL_DAYS], 56, Color.WHITE, Metal.GOLD, false)
		var bx := r.position.x + 300
		Metal.slant_bar(self, Rect2(bx, r.position.y + 30, 260, 34), float(done) / 4.0, Color("ffe08a"), Color("b07a22"), -1.0, 1, 10.0, Color(1, 1, 1, 0.5))
