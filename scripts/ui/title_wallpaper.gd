class_name TitleWallpaper
extends Control
## The game's key-art wallpaper, alive: the Solar Altar plateau under the eclipse; Auren behind
## the altar with the Centroid glowing on it; Seran leading the seven guardians on the right and
## Veyr leading the seven traitors on the left. Every figure is a painted cut-out that breathes
## and sways a little; embers rise, motes circle the Centroid, the whole scene drifts in depth.
##
## Art: assets/title/plate.png (empty background) and assets/title/<id>.png (cut-outs with alpha).
## A missing cut-out is simply left out, so the wallpaper still works while art is being made.

const DIR := "res://assets/title/"

## id: [x (fraction of width), feet y (fraction of height), height (fraction of height), row]
## row 0 = front (leaders), 1 = middle, 2 = back. Traitors left, guardians right.
const LAYOUT := {
	"zerin": [0.095, 0.80, 0.47, 2], "nyra": [0.155, 0.79, 0.46, 2], "vaska": [0.225, 0.78, 0.45, 2], "corvin": [0.295, 0.77, 0.44, 2],
	"iren": [0.705, 0.77, 0.44, 2], "mira": [0.775, 0.78, 0.45, 2], "oren": [0.845, 0.79, 0.46, 2], "lyra": [0.905, 0.80, 0.47, 2],
	"rhex": [0.065, 1.00, 0.60, 1], "mael": [0.16, 0.98, 0.59, 1], "thane": [0.25, 0.96, 0.58, 1],
	"kael": [0.75, 0.96, 0.58, 1], "darin": [0.84, 0.98, 0.60, 1], "tala": [0.935, 1.00, 0.59, 1],
	"auren": [0.5, 0.78, 0.52, 1],
	"veyr": [0.345, 1.06, 0.76, 0], "seran": [0.655, 1.06, 0.76, 0],
}
## cut-outs that were painted facing away from the altar, mirrored so everyone faces the centre
const FLIP: Array[String] = ["seran", "veyr", "lyra", "nyra"]

var centroid_at := Vector2(0.5, 0.60)   # set from the altar's top once it is placed
var centroid_shown := 1.0               # the boot loader hides it while its own crystal orbits
var _t := 0.0
var _plate: TextureRect
var _figures: Array[Dictionary] = []
var _altar: TextureRect
var _fx: _Glow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_plate = TextureRect.new()
	_plate.texture = _tex("plate", "res://assets/backdrops/solar_altar.png")
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	# back row, middle row, Auren, the altar, then the two leaders in front
	for row in [2, 1]:
		for id in LAYOUT:
			if int(LAYOUT[id][3]) == row and id != "auren":
				_add_figure(id)
	_add_figure("auren")
	var at: Texture2D = _tex("altar", "")
	if at:
		_altar = TextureRect.new()
		_altar.texture = at
		_altar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_altar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		_altar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_altar)
	_fx = _Glow.new()
	_fx.wall = self
	add_child(_fx)
	_add_figure("veyr")
	_add_figure("seran")
	add_child(_embers())
	var vig := _Vignette.new()
	add_child(vig)
	resized.connect(_layout)
	_layout()


static func _tex(id: String, fallback: String) -> Texture2D:
	var p := DIR + id + ".png"
	if ResourceLoader.exists(p):
		return load(p)
	if fallback != "" and ResourceLoader.exists(fallback):
		return load(fallback)
	return null


func _add_figure(id: String) -> void:
	var tx: Texture2D = _tex(id, "")
	if tx == null:
		return
	var r := TextureRect.new()
	r.texture = tx
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spec: Array = LAYOUT[id]
	var row := int(spec[3])
	var x := float(spec[0])
	var on_right := x > 0.5
	r.flip_h = FLIP.has(id)
	# depth: back rows darker and cooler; each side tinted by its light (gold right, violet left)
	var dim: float = [1.0, 0.82, 0.62][row]
	if id == "auren":
		dim = 0.95
	var tint := Color(1.0, 0.97, 0.92) if on_right else Color(0.95, 0.92, 1.0)
	if id == "auren":
		tint = Color(1.0, 0.96, 0.88)
	r.modulate = Color(tint.r * dim, tint.g * dim, tint.b * dim)
	add_child(r)
	_figures.append({"node": r, "id": id, "ph": randf() * TAU})


func _layout() -> void:
	var w := size.x
	var h := size.y
	_plate.position = Vector2(-w * 0.03, -h * 0.03)
	_plate.size = Vector2(w * 1.06, h * 1.06)
	for f in _figures:
		var r: TextureRect = f["node"]
		var spec: Array = LAYOUT[f["id"]]
		var tx := r.texture
		var fh := h * float(spec[2])
		var fw := fh * tx.get_width() / float(tx.get_height())
		r.size = Vector2(fw, fh)
		r.pivot_offset = Vector2(fw * 0.5, fh)
		f["base"] = Vector2(w * float(spec[0]) - fw * 0.5, h * float(spec[1]) - fh)
		r.position = f["base"]
	if _altar:
		var ah := h * 0.36
		var aw := ah * _altar.texture.get_width() / float(_altar.texture.get_height())
		_altar.size = Vector2(aw, ah)
		_altar.position = Vector2(w * 0.5 - aw * 0.5, h * 1.0 - ah)
		centroid_at = Vector2(0.5, (h - ah * 1.05) / h)
	_fx.size = size


func _process(delta: float) -> void:
	_t += delta
	var w := size.x
	# slow drift: the plate and each row move a little differently (depth)
	var drift := sin(_t * 0.12)
	_plate.position.x = -w * 0.03 + drift * w * 0.006
	for f in _figures:
		var r: TextureRect = f["node"]
		var spec: Array = LAYOUT[f["id"]]
		var row := int(spec[3])
		var depth: float = [1.0, 0.6, 0.35][row]
		var ph: float = f["ph"]
		r.position = f["base"] + Vector2(drift * w * 0.012 * depth, 0.0)
		# breathing: a slow rise of the chest and a slight sway
		r.scale = Vector2(1.0, 1.0 + 0.008 * sin(_t * 1.4 + ph))
		r.rotation = 0.006 * sin(_t * 0.7 + ph)


func _embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 70
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1300, 10)
	p.position = Vector2(1200, 1120)
	p.direction = Vector2(0.1, -1)
	p.spread = 25.0
	p.gravity = Vector2(6, -18)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 0.6, 0.2, 0), Color(1, 0.7, 0.3, 0.9), Color(1, 0.45, 0.15, 0.6), Color(1, 0.3, 0.1, 0)])
	p.color_ramp = g
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p


## The Centroid on the altar: its glow on the scene, motes circling it, the crystal itself.
class _Glow extends Control:
	var wall: TitleWallpaper
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var c := Vector2(size.x * wall.centroid_at.x, h * wall.centroid_at.y)
		var pulse := 0.85 + 0.15 * sin(t * 1.6)
		for i in 10:
			var k := float(i) / 9.0
			draw_circle(c, h * (0.45 - k * 0.4) * pulse, Color(1.0, 0.8, 0.4, 0.008 + 0.03 * k * k))
		for i in 14:
			var a := t * (0.5 + 0.07 * i) + i * 2.4
			var rr := h * (0.06 + 0.012 * (i % 5))
			var mp := c + Vector2(cos(a) * rr * 1.6, sin(a) * rr * 0.5 - h * 0.01)
			draw_circle(mp, h * 0.003 * (1.0 + 0.5 * sin(t * 3.0 + i)), Color(1.0, 0.9, 0.6, 0.8))
		if wall.centroid_shown > 0.01:
			modulate.a = wall.centroid_shown
			LoadingRing.draw_centroid(self, c, h * 0.06, t)


class _Vignette extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# top and bottom bands so the logo and the menu read
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.22), Vector2(0, h * 0.22)]),
			PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.72), Vector2(w, h * 0.72), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.7)]))
