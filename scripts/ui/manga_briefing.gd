class_name MangaBriefing
extends Control
## Pre-fight manga page: what both fighters' powers do and how to answer the enemy's.
## Shown before round 1 and from the pause menu ("Moves"). The panels ink in one after
## another; a tap reveals the whole page, SKIP or FIGHT! closes it.

signal closed

const PAPER := Color("07080c")
const INK := Color("f2efe8")
const GOLD := Color(0.92, 0.78, 0.5)
const CAP_BG := Color(0.05, 0.06, 0.09, 0.93)
const STEP := 0.2          # seconds between panel reveals
const FADE := 0.22

var player: Dictionary = {}
var enemy: Dictionary = {}
var player_id := ""
var enemy_id := ""
var counters: Array = []
var fight_title := ""
var from_pause := false

var _t := 0.0
var _panes: Array[Pane] = []
var _skip: Pane
var _go: Pane
var _closing := false
var _sounded := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	_layout()


# ------------------------------------------------------------------ layout

func _layout() -> void:
	var w := size.x
	var h := size.y
	var k := h / 1080.0
	var m := 36.0 * k
	var g := 16.0 * k
	var head_h := 190.0 * k
	var pow_h := 470.0 * k
	var y0 := m + head_h + g
	var y1 := y0 + pow_h + g
	var low_h := h - m - y1

	_add(Pane.new(self, "header", Rect2(m, m, w - 2 * m, head_h), {}))

	# four power panels: the player's two, a wider gutter, the enemy's two
	var split := 26.0 * k
	var cw := (w - 2 * m - 2 * g - split) / 4.0
	var ppow: Array = player.get("powers", [])
	var epow: Array = enemy.get("powers", [])
	for i in 4:
		var mine := i < 2
		var list: Array = ppow if mine else epow
		var j := i % 2
		if j >= list.size():
			continue
		var x := m + i * (cw + g) + (split - g if not mine else 0.0)
		_add(Pane.new(self, "power", Rect2(x, y0, cw, pow_h), {
			"power": list[j], "index": j + 1, "who": player if mine else enemy,
			"id": player_id if mine else enemy_id, "mine": mine}))

	# counters, then the FIGHT! panel
	var go_w := w * 0.17
	var n := mini(2, counters.size())
	var ccw := (w - 2 * m - go_w - g * n) / maxf(1.0, float(n))
	for c in n:
		var cdef: Dictionary = counters[c]
		var threat := {}
		var ti := 0
		for i in epow.size():
			if epow[i].get("id", "") == cdef.get("threat", ""):
				threat = epow[i]
				ti = i + 1
		_add(Pane.new(self, "counter", Rect2(m + c * (ccw + g), y1, ccw, low_h), {
			"threat": threat, "index": ti, "answers": cdef.get("answers", []), "tip": String(cdef.get("tip", ""))}))
	_go = Pane.new(self, "go", Rect2(w - m - go_w, y1, go_w, low_h), {})
	_add(_go)

	var sw := 150.0 * k
	_skip = Pane.new(self, "skip", Rect2(w - m - sw - 14 * k, m + 14 * k, sw, 54 * k), {})
	_skip.at = 0.0
	add_child(_skip)


func _add(p: Pane) -> void:
	p.at = 0.12 + _panes.size() * STEP
	_panes.append(p)
	add_child(p)


func _all_shown() -> bool:
	return _panes.is_empty() or _t >= _panes[-1].at + FADE


# ------------------------------------------------------------------ flow

func _process(delta: float) -> void:
	_t += delta
	for i in _panes.size():
		var p := _panes[i]
		var a := clampf((_t - p.at) / FADE, 0.0, 1.0)
		p.modulate.a = a
		p.position = p.home + Vector2(0, (1.0 - ease(a, 0.5)) * 26.0)
		p.queue_redraw()
		if a > 0.0 and i >= _sounded:
			_sounded = i + 1
			if i > 0:
				AudioManager.sfx("panel_in", -12.0)
	if _skip:
		_skip.modulate.a = clampf(_t / 0.3, 0.0, 1.0)
	if _go:
		_go.queue_redraw()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	else:
		return
	accept_event()
	if _closing or _t < 0.25:
		return
	if _skip and _skip.get_rect().grow(20).has_point(pos):
		_close()
	elif not _all_shown():
		_t = _panes[-1].at + FADE   # show the whole page at once
		_sounded = _panes.size()
		AudioManager.sfx("page_turn", -6.0)
	else:
		_close()


func _close() -> void:
	_closing = true
	AudioManager.sfx("ui_confirm")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	await tw.finished
	closed.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)


# ------------------------------------------------------------------ helpers

## Splash art for a fighter's power (1 or 2). Kept in a cache: a texture loaded inside
## _draw and then dropped is freed before the frame renders and shows up blank.
static var _art_cache: Dictionary = {}

static func art_for(id: String, index: int) -> Texture2D:
	var path := "res://assets/cutins/cutin_%s_%d.webp" % [id, index]
	if not _art_cache.has(path):
		_art_cache[path] = load(path) if index > 0 and ResourceLoader.exists(path) else null
	return _art_cache[path]


## Draws `tex` covering `rect` (cropped, never stretched), centred on `focus` (0..1 of the art).
static func draw_cover(ci: CanvasItem, tex: Texture2D, rect: Rect2, focus := Vector2(0.5, 0.36), tint := Color.WHITE) -> void:
	if tex == null:
		return
	var aw := float(tex.get_width())
	var ah := float(tex.get_height())
	var a := rect.size.x / rect.size.y
	var src := Rect2()
	if a > aw / ah:
		src.size = Vector2(aw, aw / a)
	else:
		src.size = Vector2(ah * a, ah)
	src.position = Vector2(clampf(focus.x * aw - src.size.x * 0.5, 0.0, aw - src.size.x),
		clampf(focus.y * ah - src.size.y * 0.5, 0.0, ah - src.size.y))
	ci.draw_texture_rect_region(tex, rect, src, tint)


## The same crop as draw_cover, but filling a polygon (slanted panels).
static func draw_cover_poly(ci: CanvasItem, tex: Texture2D, pts: PackedVector2Array, rect: Rect2, focus := Vector2(0.5, 0.36), tint := Color.WHITE) -> void:
	if tex == null:
		return
	var aw := float(tex.get_width())
	var ah := float(tex.get_height())
	var a := rect.size.x / rect.size.y
	var s := Vector2(1, aw / a / ah) if a > aw / ah else Vector2(ah * a / aw, 1)
	var o := Vector2(clampf(focus.x - s.x * 0.5, 0.0, 1.0 - s.x), clampf(focus.y - s.y * 0.5, 0.0, 1.0 - s.y))
	var uvs := PackedVector2Array()
	for p in pts:
		var q := (p - rect.position) / rect.size
		uvs.append(o + q * s)
	ci.draw_colored_polygon(pts, tint, uvs, tex)


static func wrap(f: Font, text: String, fs: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in text.split(" ", false):
		var trial := word if cur == "" else cur + " " + word
		if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out


static func text_w(f: Font, s: String, fs: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Manga lettering: thick dark outline under the fill.
static func letter(ci: CanvasItem, f: Font, p: Vector2, s: String, fs: int, col: Color, outline := 0) -> void:
	var o := outline if outline > 0 else maxi(4, fs / 6)
	ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, o, Color(0.01, 0.01, 0.02, 0.96))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func caption_box(ci: CanvasItem, r: Rect2, k: float) -> void:
	ci.draw_rect(r, CAP_BG)
	ci.draw_rect(r, Color(GOLD, 0.9), false, maxf(2.0, 3.0 * k))


## Touch-button icon in a ring, as on the fight controls.
static func button(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, Color(0.02, 0.03, 0.06, 0.92))
	ci.draw_circle(c, r, Color(col, 0.2))
	ci.draw_arc(c, r, 0, TAU, 40, col, maxf(3.0, r * 0.09), true)
	if kind == "back":
		var s := r * 0.55
		ci.draw_line(c + Vector2(s, 0), c + Vector2(-s * 0.4, 0), Color.WHITE, maxf(4.0, r * 0.13))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s * 0.3, -s * 0.6), c + Vector2(-s * 0.3, s * 0.6)]), Color.WHITE)
	else:
		ButtonIcons.draw(ci, kind, c, r, Color.WHITE)


## [icon, colour, label] for a counter answer ("jump", "block", "back", "power_2", ...).
func answer(a: String) -> Array:
	var pcol := Color(player.get("color", "#ffffff")).lightened(0.2)
	match a:
		"jump": return ["jump", Color(0.6, 1.0, 0.72), "JUMP"]
		"block": return ["block", Color(0.62, 0.8, 1.0), "BLOCK"]
		"back": return ["back", Color(0.85, 0.85, 0.9), "BACK OFF"]
		"attack_light": return ["attack_light", Color(0.9, 0.92, 1.0), "LIGHT"]
		"attack_heavy": return ["attack_heavy", Color(1.0, 0.72, 0.42), "HEAVY"]
	if a.begins_with("power_"):
		var i := int(a.substr(6)) - 1
		var ppow: Array = player.get("powers", [])
		if i >= 0 and i < ppow.size():
			return [ButtonIcons.for_power(ppow[i]), pcol, String(ppow[i].get("name", "")).to_upper()]
	return ["burst", Color.WHITE, a.to_upper()]


static func stats(p: Dictionary) -> String:
	var parts: Array[String] = ["COST %d" % int(p.get("cost", 0))]
	if p.has("damage"):
		parts.append("DMG %d" % int(p.get("damage", 0)))
	if p.has("heal"):
		parts.append("HEAL %d" % int(p.get("heal", 0)))
	if p.has("duration"):
		parts.append("%s s" % str(snappedf(float(p.get("duration", 0.0)), 0.1)).trim_suffix(".0"))
	return "  ·  ".join(parts)


# ======================================================================= pane

class Pane extends Control:
	var book: MangaBriefing
	var kind := ""
	var info: Dictionary = {}
	var at := 0.0
	var home := Vector2.ZERO

	func _init(b: MangaBriefing, k: String, r: Rect2, d: Dictionary) -> void:
		book = b
		kind = k
		info = d
		position = r.position
		home = r.position
		size = r.size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0

	func _draw() -> void:
		match kind:
			"header": _header()
			"power": _power()
			"counter": _counter()
			"go": _go()
			"skip": _skip()

	func _k() -> float:
		return book.size.y / 1080.0

	func _frame(pts: PackedVector2Array) -> void:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, INK, 5.0 * _k(), true)

	# ---- "KAEL  VS  RHEX": two slanted halves meeting at a VS burst
	func _header() -> void:
		var k := _k()
		var w := size.x
		var h := size.y
		var mid := w * 0.5
		var cut := 70.0 * k
		var gap := 10.0 * k
		var r := Rect2(Vector2.ZERO, size)
		var lp := PackedVector2Array([Vector2(0, 0), Vector2(mid + cut - gap, 0), Vector2(mid - cut - gap, h), Vector2(0, h)])
		var rp := PackedVector2Array([Vector2(mid + cut + gap, 0), Vector2(w, 0), Vector2(w, h), Vector2(mid - cut + gap, h)])
		var pcol := Color(book.player.get("color", "#ffffff"))
		var ecol := Color(book.enemy.get("color", "#ff6644"))
		var lt := MangaBriefing.art_for(book.player_id, 1)
		var rt := MangaBriefing.art_for(book.enemy_id, 1)
		var lr := Rect2(0, 0, mid + cut, h)
		var rr := Rect2(mid - cut, 0, w - mid + cut, h)
		if lt:
			MangaBriefing.draw_cover_poly(self, lt, lp, lr, Vector2(0.5, 0.33), Color(0.78, 0.78, 0.82))
		else:
			draw_colored_polygon(lp, pcol.darkened(0.7))
		if rt:
			MangaBriefing.draw_cover_poly(self, rt, rp, rr, Vector2(0.5, 0.33), Color(0.78, 0.78, 0.82))
		else:
			draw_colored_polygon(rp, ecol.darkened(0.7))
		# colour wash toward the centre so the names read
		var steps := 16
		for s in steps:
			var f := float(s) / steps
			var a := 0.62 * (1.0 - f)
			var bw := w * 0.3 / steps
			draw_rect(Rect2(mid - cut - (s + 1) * bw, 0, bw + 1, h), Color(pcol.darkened(0.82), a))
			draw_rect(Rect2(mid + cut + s * bw, 0, bw + 1, h), Color(ecol.darkened(0.82), a))
		_frame(lp)
		_frame(rp)
		# names
		var tf := UiStyle.title_font()
		var fs := int(92 * k)
		var pn := String(book.player.get("name", "")).to_upper()
		var en := String(book.enemy.get("name", "")).to_upper()
		var by := h * 0.5 + fs * 0.36
		MangaBriefing.letter(self, tf, Vector2(mid - cut - 60 * k - MangaBriefing.text_w(tf, pn, fs), by), pn, fs, pcol.lightened(0.35))
		MangaBriefing.letter(self, tf, Vector2(mid + cut + 60 * k, by), en, fs, ecol.lightened(0.3))
		# the VS burst
		var c := Vector2(mid, h * 0.5)
		var pts := PackedVector2Array()
		var n := 18
		for i in n:
			var ang := TAU * i / n + 0.1
			var rad := (h * 0.56 if i % 2 == 0 else h * 0.36)
			pts.append(c + Vector2(cos(ang) * rad * 1.2, sin(ang) * rad))
		draw_colored_polygon(pts, Color(0.98, 0.96, 0.92))
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Color(0.02, 0.02, 0.03), 4.0 * k, true)
		var vf := int(70 * k)
		var vs := "VS"
		MangaBriefing.letter(self, tf, c + Vector2(-MangaBriefing.text_w(tf, vs, vf) * 0.5, vf * 0.36), vs, vf, Color(0.85, 0.1, 0.08), int(5 * k))
		# fight number tag
		if book.fight_title != "":
			var bf := UiStyle.bold_font()
			var tfs := int(26 * k)
			var tag := book.fight_title.to_upper()
			var tr := Rect2(16 * k, 14 * k, MangaBriefing.text_w(bf, tag, tfs) + 28 * k, 44 * k)
			MangaBriefing.caption_box(self, tr, k)
			draw_string(bf, tr.position + Vector2(14 * k, tr.size.y * 0.5 + tfs * 0.36), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, GOLD)

	# ---- one power: splash art, owner tab, button icon, caption with name / what it does / cost
	func _power() -> void:
		var k := _k()
		var r := Rect2(Vector2.ZERO, size)
		var p: Dictionary = info["power"]
		var who: Dictionary = info["who"]
		var col := Color(who.get("color", "#ffffff"))
		var tex := MangaBriefing.art_for(String(info["id"]), int(info["index"]))
		if tex:
			MangaBriefing.draw_cover(self, tex, r, Vector2(0.5, 0.42))
		else:
			draw_rect(r, col.darkened(0.75))
		draw_rect(r, INK, false, 5.0 * k)
		var bf := UiStyle.bold_font()
		var uf := UiStyle.ui_font()
		# owner tab
		var tfs := int(24 * k)
		var tag := "%s · POWER %d" % [String(who.get("name", "")).to_upper(), int(info["index"])]
		if not info["mine"]:
			tag = "ENEMY · " + tag
		var tr := Rect2(12 * k, 12 * k, MangaBriefing.text_w(bf, tag, tfs) + 24 * k, 40 * k)
		draw_rect(tr, Color(col.darkened(0.55), 0.92))
		draw_rect(tr, col.lightened(0.2), false, 2.0 * k)
		draw_string(bf, tr.position + Vector2(12 * k, tr.size.y * 0.5 + tfs * 0.36), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color.WHITE)
		# the button it lives on
		var ir := 38.0 * k
		MangaBriefing.button(self, ButtonIcons.for_power(p), Vector2(size.x - ir - 14 * k, ir + 14 * k), ir, col.lightened(0.2))
		# caption
		var pad := 16.0 * k
		var nfs := int(40 * k)
		var dfs := int(25 * k)
		var lines := MangaBriefing.wrap(uf, String(p.get("desc", "")), dfs, size.x - 2 * pad - 20 * k)
		var lh := uf.get_height(dfs) * 1.12
		var ch := pad + nfs * 1.05 + lines.size() * lh + 8 * k + 30 * k + pad
		var cr := Rect2(10 * k, size.y - ch - 10 * k, size.x - 20 * k, ch)
		MangaBriefing.caption_box(self, cr, k)
		var y := cr.position.y + pad + nfs * 0.82
		draw_string(bf, Vector2(cr.position.x + pad, y), String(p.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, col.lightened(0.4))
		y += nfs * 0.3
		for line in lines:
			y += lh
			draw_string(uf, Vector2(cr.position.x + pad, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color(0.92, 0.9, 0.86))
		y += 14 * k + 22 * k
		draw_string(bf, Vector2(cr.position.x + pad, y), MangaBriefing.stats(p), HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * k), GOLD)

	# ---- enemy power -> your answer buttons, with a tip
	func _counter() -> void:
		var k := _k()
		var r := Rect2(Vector2.ZERO, size)
		var threat: Dictionary = info["threat"]
		var ecol := Color(book.enemy.get("color", "#ff6644"))
		var tex := MangaBriefing.art_for(book.enemy_id, int(info["index"]))
		if tex:
			MangaBriefing.draw_cover(self, tex, r, Vector2(0.5, 0.5), Color(0.32, 0.3, 0.34))
		else:
			draw_rect(r, ecol.darkened(0.85))
		draw_rect(r, INK, false, 5.0 * k)
		var bf := UiStyle.bold_font()
		var uf := UiStyle.ui_font()
		# title tag
		var tfs := int(26 * k)
		var tag := "COUNTER · " + String(threat.get("name", "")).to_upper()
		var tr := Rect2(12 * k, 12 * k, MangaBriefing.text_w(bf, tag, tfs) + 26 * k, 42 * k)
		MangaBriefing.caption_box(self, tr, k)
		draw_string(bf, tr.position + Vector2(13 * k, tr.size.y * 0.5 + tfs * 0.36), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, GOLD)
		# threat icon -> answers
		var cy := size.y * 0.43
		var tr2 := 44.0 * k
		var x := 30.0 * k + tr2
		MangaBriefing.button(self, ButtonIcons.for_power(threat), Vector2(x, cy), tr2, ecol)
		var ax := x + tr2 + 18 * k
		draw_line(Vector2(ax, cy), Vector2(ax + 50 * k, cy), INK, 5.0 * k)
		draw_colored_polygon(PackedVector2Array([Vector2(ax + 66 * k, cy), Vector2(ax + 46 * k, cy - 13 * k), Vector2(ax + 46 * k, cy + 13 * k)]), INK)
		var ans: Array = info["answers"]
		var ar := 38.0 * k
		var px := ax + 66 * k + 24 * k + ar
		var lfs := int(20 * k)
		for i in ans.size():
			var a: Array = book.answer(String(ans[i]))
			if i > 0:
				var orw := MangaBriefing.text_w(bf, "OR", lfs)
				draw_string(bf, Vector2(px - orw * 0.5, cy + lfs * 0.36), "OR", HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(INK, 0.7))
				px += orw + 20 * k + ar
			MangaBriefing.button(self, a[0], Vector2(px, cy), ar, a[1])
			var lw := MangaBriefing.text_w(bf, a[2], lfs)
			MangaBriefing.letter(self, bf, Vector2(px - lw * 0.5, cy + ar + 26 * k), a[2], lfs, Color.WHITE, int(4 * k))
			px += ar * 2 + 20 * k + maxf(0.0, lw - ar * 2) * 0.5
		# tip
		var tip: String = info["tip"]
		if tip != "":
			var pad := 14.0 * k
			var dfs := int(27 * k)
			var lines := MangaBriefing.wrap(uf, tip, dfs, size.x - 2 * pad - 24 * k)
			var lh := uf.get_height(dfs) * 1.1
			var ch := pad * 2 + lines.size() * lh
			var cr := Rect2(10 * k, size.y - ch - 10 * k, size.x - 20 * k, ch)
			MangaBriefing.caption_box(self, cr, k)
			for i in lines.size():
				draw_string(uf, Vector2(cr.position.x + pad, cr.position.y + pad + lh * i + uf.get_ascent(dfs)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color(0.94, 0.92, 0.88))

	# ---- FIGHT! (or RESUME from the pause menu)
	func _go() -> void:
		var k := _k()
		var w := size.x
		var h := size.y
		var pcol := Color(book.player.get("color", "#ffffff"))
		draw_rect(Rect2(Vector2.ZERO, size), pcol.darkened(0.72))
		# speed lines toward the centre
		var c := Vector2(w * 0.5, h * 0.5)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 46:
			var ang := rng.randf() * TAU
			var r0 := rng.randf_range(0.3, 0.55) * h
			var d := Vector2(cos(ang), sin(ang))
			# run to the panel edge, not past it
			var reach := minf(absf((w * 0.5 - 4.0) / d.x) if absf(d.x) > 0.001 else 1e9, absf((h * 0.5 - 4.0) / d.y) if absf(d.y) > 0.001 else 1e9)
			if reach > r0:
				draw_line(c + d * r0, c + d * reach, Color(pcol.lightened(0.5), 0.35), rng.randf_range(2.0, 6.0) * k)
		draw_rect(Rect2(Vector2.ZERO, size), INK, false, 5.0 * k)
		var ready := book._all_shown()
		var pulse := 1.0 + (0.06 * sin(book._t * 6.0) if ready else 0.0)
		var tf := UiStyle.title_font()
		var txt := "RESUME" if book.from_pause else "FIGHT!"
		var fs := int(minf(78.0 * k, w * 0.9 / maxf(1.0, MangaBriefing.text_w(tf, txt, 78) / 78.0)) * pulse)
		var tw := MangaBriefing.text_w(tf, txt, fs)
		MangaBriefing.letter(self, tf, Vector2(c.x - tw * 0.5, c.y + fs * 0.34), txt, fs, Color(1, 0.97, 0.9) if ready else Color(1, 1, 1, 0.45), int(7 * k))
		var bf := UiStyle.bold_font()
		var sfs := int(22 * k)
		var hint := "TAP" if ready else "TAP TO READ ALL"
		var hw := MangaBriefing.text_w(bf, hint, sfs)
		draw_string(bf, Vector2(c.x - hw * 0.5, h - 24 * k), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(GOLD, 0.6 + 0.4 * sin(book._t * 4.0)))

	func _skip() -> void:
		var k := _k()
		var r := Rect2(Vector2.ZERO, size)
		MangaBriefing.caption_box(self, r, k)
		var bf := UiStyle.bold_font()
		var fs := int(28 * k)
		var s := "SKIP  >>"
		var tw := MangaBriefing.text_w(bf, s, fs)
		draw_string(bf, Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
