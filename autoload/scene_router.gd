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
	"jump": [KEY_W, KEY_UP, KEY_SPACE],
	"attack_light": [KEY_J],
	"attack_heavy": [KEY_K],
	"block": [KEY_L, KEY_S, KEY_DOWN],
	"power_1": [KEY_U],
	"power_2": [KEY_I],
	"advance": [KEY_ENTER, KEY_KP_ENTER],
}

var current: Dictionary = {}
var _fade: ColorRect
var _busy := false


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
