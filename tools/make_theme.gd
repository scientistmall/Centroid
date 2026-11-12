extends SceneTree
## Saves UiStyle.theme() as res://assets/ui_theme.tres (the project-wide default theme).
##   godot --headless -s res://tools/make_theme.gd

func _initialize() -> void:
	var t: Theme = UiStyle.theme()
	var err := ResourceSaver.save(t, "res://assets/ui_theme.tres")
	print("saved theme: ", error_string(err))
	quit()
