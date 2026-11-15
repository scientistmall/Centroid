extends Node
## Reads every story scene start to end like a player and checks that every speech bubble and
## caption is fully visible: inside its panel (panels clip), not under another panel, and every
## wrapped line fits its bubble.
##   godot --path . --resolution 2400x1080 res://tests/story_layout_test.tscn [-- scene ...]

const SCENES := ["prologue", "ch01_pre", "ch01_post", "ch02_pre", "ch02_post", "ch03_pre", "ch03_post",
	"ch04_pre", "ch04_post"]

var bad := 0
var checked := 0
var shot_n := 0


func _ready() -> void:
	SceneRouter._busy = true
	StoryManager.new_game()
	var only := OS.get_cmdline_user_args()
	for id in SCENES:
		if only.is_empty() or only.has(id):
			if ResourceLoader.exists("res://data/story/%s.story" % id) or FileAccess.file_exists("res://data/story/%s.story" % id):
				await _run(id)
	print("STORY LAYOUT: %d bubbles checked, %d problems" % [checked, bad])
	get_tree().quit(1 if bad else 0)


func _run(id: String) -> void:
	SceneRouter.current = {"type": "story", "id": id}
	var sp = load("res://scenes/story/story_player.tscn").instantiate()
	sp.set("next_dest", {"type": "none"})
	add_child(sp)
	await get_tree().process_frame
	var seen := {}
	var guard := 0
	while not sp._finished and guard < 6000:
		guard += 1
		sp._card_elapsed = 99.0
		while sp._blocked:
			await get_tree().process_frame
		if sp.index >= sp.steps.size() - 1:
			break
		sp._on_tap()
		await get_tree().process_frame
		if sp._typing and not seen.has(sp._typing):
			seen[sp._typing] = true
			await get_tree().process_frame
			await _check(id, sp, sp._typing)
	sp.queue_free()
	await get_tree().process_frame


func _check(id: String, sp, b) -> void:
	checked += 1
	var pv: Control = b.get_parent()
	var r := Rect2(b.position, b.size)
	var pr := Rect2(Vector2.ZERO, pv.size)
	var why := []
	if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > pr.end.x + 0.5 or r.end.y > pr.end.y + 0.5:
		why.append("outside its panel %s in %s" % [r, pr.size])
	var inner: float = b.size.x - b._pad.x * 2.0
	for l in b._lines:
		var w: float = b._font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, int(b._fs)).x
		if w > inner + 1.0:
			why.append("line wider than bubble: '%s'" % l)
	# covered by a panel drawn above it on the same page
	var g := Rect2(pv.position + b.position, b.size)
	var page: Control = pv.get_parent()
	for other in page.get_children():
		if other == pv or not ("rect" in other) or other.get_index() < pv.get_index():
			continue
		if Rect2(other.position, other.size).intersects(g):
			why.append("covered by another panel")
			break
	if pv.get("cleared") and int(pv.cleared) > int(pv.get_meta("reported", 0)):
		pv.set_meta("reported", pv.cleared)
		why.append("older text in this panel was removed to make room")
	var shots := OS.get_environment("STORY_SHOTS")
	if shots != "" and float(pv.get("_k")) < 0.999 and not pv.has_meta("shot") and shot_n < 3:
		pv.set_meta("shot", true)
		shot_n += 1
		for i in 30: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/refit_%d.png" % [shots, shot_n])
	if not why.is_empty():
		bad += 1
		print("PROBLEM %s step %d: \"%s\" -> %s" % [id, sp.index, String(b.text).left(60), ", ".join(why)])
