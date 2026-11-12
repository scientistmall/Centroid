extends Node2D
## Dev tool: renders portraits (all expressions) to a PNG for art review.
##   xvfb-run -a godot --rendering-method gl_compatibility --resolution 2400x1080 res://tests/art_preview.tscn -- <out.png> [ids...]

var ids := ["kael", "rhex"]
var t := 0.5


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		ids = args.slice(1)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out: String = args[0] if args.size() > 0 else "user://art_preview.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 2400, 1080), Color("101018"))
	var exprs := ["neutral", "angry", "determined", "sad", "shocked", "smile"]
	var cw := 2400.0 / exprs.size()
	var ch := 1080.0 / ids.size()
	for r in ids.size():
		var look: Dictionary = PortraitArt.look_for(ids[r]).get("portrait", {})
		var accent := Color(StoryParser.character(ids[r]).get("color", "#ffffff"))
		for c in exprs.size():
			draw_set_transform(Vector2(c * cw, r * ch))
			PortraitArt.paint(self, Vector2(cw, ch), look, exprs[c], t, accent)
			draw_set_transform(Vector2.ZERO)
			draw_string(ThemeDB.fallback_font, Vector2(c * cw + 20, r * ch + 40), "%s / %s" % [ids[r], exprs[c]], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.7))
