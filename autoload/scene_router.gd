extends Node
## Moves between the main menu, story scenes and fights with a fade.
## A destination is a Dictionary: {"type": "story"|"fight"|"menu", "id": "..."}.
## The destination scene reads `SceneRouter.current` to know what to load.

const SCENES := {
	"story": "res://scenes/story/story_player.tscn",
	"fight": "res://scenes/fight/arena.tscn",
	"menu": "res://scenes/main_menu.tscn",
	"chapters": "res://scenes/ui/chapter_select.tscn",
}

## Default keyboard bindings (useful on PC; phones use the touch controls).
const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"attack_light": [KEY_J],
	"attack_medium": [],
	"dash_back": [],
	"attack_heavy": [KEY_K],
	"block": [KEY_L, KEY_S, KEY_DOWN],
	"power_1": [KEY_U],
	"power_2": [KEY_I],
	"power_3": [KEY_O],
	"power": [KEY_P],
	"advance": [KEY_ENTER, KEY_KP_ENTER],
}

var current: Dictionary = {}
var _fade: ColorRect
var _busy := false
var _exit_armed := 0.0      # main menu: a second back press within this window exits
var _toast: Label
var _fps: Label
var _fps_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = -170
	_toast.offset_bottom = -110
	_toast.add_theme_font_size_override("font_size", 34)
	_toast.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	layer.add_child(_toast)
	_fps = Label.new()
	_fps.position = Vector2(14, 150)
	_fps.add_theme_font_size_override("font_size", 24)
	_fps.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fps.add_theme_constant_override("outline_size", 8)
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.visible = false
	layer.add_child(_fps)


## A short message near the bottom of the screen (fades out by itself).
func toast(text: String, secs := 2.5) -> void:
	_toast.text = text
	_exit_armed = 0.0
	_toast_t = secs


var _toast_t := 0.0


func _process(delta: float) -> void:
	_toast_t = maxf(0.0, _toast_t - delta)
	# "Show FPS" (Settings): frame rate, and in a fight the 3D render scale and graphics level
	_fps.visible = Settings.show_fps
	if Settings.show_fps:
		_fps_t -= delta
		if _fps_t <= 0.0:
			_fps_t = 0.25
			var txt := "%d FPS" % int(Engine.get_frames_per_second())
			if Stage3D.current and is_instance_valid(Stage3D.current):
				txt += "  ·  3D %d%%  ·  %s" % [int(round(Stage3D.current.render_scale * 100.0)),
					["AUTO", "HIGH", "LOW", "SAFE"][Stage3D.current.level]]
			_fps.text = txt
	_exit_armed = maxf(0.0, _exit_armed - delta)
	_toast.modulate.a = clampf(maxf(_exit_armed, _toast_t), 0.0, 1.0)


# ---------------------------------------------------------------- back button
# The phone's back button (and Esc on a PC) never quits from inside the game. It closes the
# top-most thing first: any node in the "back" group with on_back() -> bool (the later in the
# tree, the more on top) gets the first say. Otherwise a story / fight / chapter screen goes back
# to the main menu, and on the main menu a second press within two seconds exits.

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back()


func back() -> void:
	if _busy:
		return
	var top: Node = null
	for n in get_tree().get_nodes_in_group("back"):
		if not n.is_inside_tree() or not n.has_method("on_back"):
			continue
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		if top == null or n.is_greater_than(top):
			top = n
	if top and top.on_back():
		return
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == SCENES["menu"]:
		if _exit_armed > 0.0:
			get_tree().quit()
		else:
			_exit_armed = 2.0
			_toast.text = "Press back again to exit"
		return
	go({"type": "menu"})


func _setup_input() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func go(dest: Dictionary, fade_time: float = 0.45) -> void:
	if _busy:
		return
	var type: String = dest.get("type", "menu")
	if not SCENES.has(type):
		push_error("Unknown destination type: %s" % type)
		type = "menu"
	_busy = true
	current = dest.duplicate()
	StoryManager.set_resume(dest)
	get_tree().paused = false
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, fade_time)
	await t.finished
	get_tree().change_scene_to_file(SCENES[type])
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, fade_time)
	await t2.finished
	_busy = false
