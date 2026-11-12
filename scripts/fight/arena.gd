extends Node2D
## Fight scene. Loads data/fights/<id>.json, runs rounds, and on victory sets
## the story flag and continues the story. Losing only offers Retry.
##
## Fight JSON fields:
##   player: ["kael"]            one id, or several for team fights
##   mode: "single"|"relay"|"tag" relay = next member enters when one falls,
##                                tag = player may swap (SWAP button)
##   enemy, arena, rounds_to_win, round_time, ai, flag, win_next

const FIGHTER_DIR := "res://data/fighters/%s.json"

var fight: Dictionary = {}
var fight_id := ""
var team: Array = []
var team_hp: Dictionary = {}
var active_idx := 0
var player: Fighter
var enemy: Fighter
var round_no := 1
var phase := "intro"
var time_left := 99.0
var ground_y := 880.0
var stage := Vector2(140, 1780)
var shake := 0.0
var swap_cooldown := 0.0
var fog: FogLayer
var _briefed := false
var ui_layer: CanvasLayer
var fog_back: FogLayer

var world: Node2D
var effects: Node2D
var hud: FightHud
var touch: TouchControls
var overlay: Control
var backdrop: Backdrop


func _ready() -> void:
	Engine.time_scale = 1.0
	fight_id = SceneRouter.current.get("id", "fight01")
	fight = _load_json("res://data/fights/%s.json" % fight_id)
	var vis := get_viewport().get_visible_rect().size
	ground_y = vis.y - 190.0
	# keep the fight between the joystick and the button cluster so fighters stay visible
	stage = Vector2(vis.x * 0.12, vis.x * 0.80) if not Settings.left_handed else Vector2(vis.x * 0.20, vis.x * 0.88)
	_build()
	_start_round()


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: %s" % path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _build() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	backdrop = Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.bg_id = fight.get("arena", "training_ground")
	bg_layer.add_child(backdrop)

	world = Node2D.new()
	add_child(world)
	effects = Node2D.new()
	effects.z_index = 5

	var p_ids = fight.get("player", ["kael"])
	team = p_ids if p_ids is Array else [p_ids]
	for id in team:
		team_hp[id] = -1.0
	enemy = _make_fighter(fight.get("enemy", "rhex"), AIController.new(clampf(float(fight.get("ai", 0.45)) * Settings.ai_multiplier(), 0.1, 1.0)))
	AudioManager.play_music(fight.get("music", "battle_1"))
	player = _make_fighter(team[0], PlayerController.new())
	player.opponent = enemy
	enemy.opponent = player
	enemy.side = 1
	world.add_child(effects)
	if fight.get("fog", false):
		fog_back = FogLayer.new()
		fog_back.z_index = -1
		world.add_child(fog_back)
		fog = FogLayer.new()
		fog.z_index = 8
		fog.strength = 0.3
		world.add_child(fog)

	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	ui_layer = ui
	hud = FightHud.new()
	hud.left = player
	hud.right = enemy
	hud.rounds_to_win = int(fight.get("rounds_to_win", 2)) if _mode() == "single" else 1
	ui.add_child(hud)
	touch = TouchControls.new()
	ui.add_child(touch)
	_update_touch_labels()
	if _mode() == "tag":
		touch.buttons.append({"action": "swap", "icon": "swap", "off": Vector2(-120, -560), "r": 56.0, "color": Color(1, 1, 0.6)})
		if not InputMap.has_action("swap"):
			InputMap.add_action("swap")
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_Q
			InputMap.action_add_event("swap", ev)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.set_anchor(SIDE_LEFT, 0.5, true)
	pause_btn.set_anchor(SIDE_RIGHT, 0.5, true)
	pause_btn.offset_left = -45
	pause_btn.offset_right = 45
	pause_btn.offset_top = 115
	pause_btn.offset_bottom = 195
	pause_btn.add_theme_font_size_override("font_size", 36)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(_pause)
	ui.add_child(pause_btn)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	ui.add_child(overlay)


func _mode() -> String:
	return fight.get("mode", "single")


func _make_fighter(id: String, ctrl: Object) -> Fighter:
	var f := Fighter.new()
	var d := _load_json(FIGHTER_DIR % id)
	d["id"] = id
	f.ground_y = ground_y
	f.stage_left = stage.x
	f.stage_right = stage.y
	f.setup(d)
	f.controller = ctrl
	f.effects_parent = effects
	f.knocked_out.connect(_on_ko)
	f.got_hit.connect(_on_hit)
	f.power_used.connect(_on_power)
	world.add_child(f)
	return f


func _update_touch_labels() -> void:
	touch.set_fighter(player)


# ---------------------------------------------------------------- rounds

func _start_round() -> void:
	phase = "intro"
	time_left = float(fight.get("round_time", 99))
	hud.time_left = time_left
	for n in effects.get_children():
		n.queue_free()
	for f in [player, enemy]:
		f.reset_for_round()
	var mid := (stage.x + stage.y) / 2.0
	player.position = Vector2(mid - 330, ground_y)
	enemy.position = Vector2(mid + 330, ground_y)
	player.facing = 1
	enemy.facing = -1
	touch.release_all()
	if round_no == 1 and not _briefed and not SceneRouter.current.get("no_briefing", false):
		_briefed = true
		touch.visible = false
		await _show_briefing().closed
		touch.visible = true
	if round_no == 1 and _mode() == "single":
		hud.banner(fight.get("title", "FIGHT"), fight.get("subtitle", ""))
		await _wait(1.6)
	hud.banner("ROUND %d" % round_no if _mode() == "single" else "READY")
	await _wait(1.0)
	hud.banner("FIGHT!")
	AudioManager.sfx("gong", -4.0)
	await _wait(0.6)
	hud.clear_banner()
	player.release()
	enemy.release()
	phase = "fight"


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false, false, true).timeout


func _physics_process(delta: float) -> void:
	if phase == "fight":
		time_left -= delta
		hud.time_left = time_left
		if time_left <= 0.0:
			_time_over()
		swap_cooldown = maxf(0.0, swap_cooldown - delta)
		if _mode() == "tag" and Input.is_action_just_pressed("swap") and swap_cooldown <= 0.0:
			_swap_member()
	_separate()
	if fog:
		var target := 0.2 if player.has_status("clear_sight") else 1.0
		fog.density = move_toward(fog.density, target, delta * 2.0)
		fog_back.density = fog.density
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 40.0)
		world.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		world.position = Vector2.ZERO


func _separate() -> void:
	if player == null or enemy == null or not player.is_alive() or not enemy.is_alive():
		return
	if player.state == Fighter.S.POWER or enemy.state == Fighter.S.POWER:
		return
	var dx := enemy.position.x - player.position.x
	var min_d := Fighter.BODY_HALF_W * 2.0
	if absf(dx) < min_d and absf(enemy.position.y - player.position.y) < 200.0:
		var push := (min_d - absf(dx)) / 2.0
		var s := signf(dx) if dx != 0.0 else 1.0
		player.position.x = clampf(player.position.x - s * push, stage.x, stage.y)
		enemy.position.x = clampf(enemy.position.x + s * push, stage.x, stage.y)


## Anime cut-in banner + a short dramatic slow-down when a power fires.
func _on_power(f: Fighter, power_name: String) -> void:
	if ui_layer == null:
		return
	for c in ui_layer.get_children():
		if c is CutIn:
			c.queue_free()
	var cut := CutIn.new()
	cut.char_id = f.char_id
	cut.accent = f.color
	cut.power_name = power_name
	cut.from_left = f.side == 0
	ui_layer.add_child(cut)
	AudioManager.sfx("cutin", -2.0)
	ui_layer.move_child(cut, 1)   # above the HUD bars, below overlays
	if phase == "fight":
		Engine.time_scale = 0.35
		await _wait(0.32)
		if phase == "fight":
			Engine.time_scale = 1.0


func _on_hit(_f: Fighter, heavy: bool) -> void:
	shake = maxf(shake, 14.0 if heavy else 6.0)


func _on_ko(f: Fighter) -> void:
	if phase != "fight":
		return
	if f == player and _next_alive_member() != -1:
		_relay_next()
		return
	_round_over(enemy if f == player else player)


func _time_over() -> void:
	phase = "end"
	var pr := player.hp / player.max_hp
	var er := enemy.hp / enemy.max_hp
	if is_equal_approx(pr, er):
		hud.banner("TIME", "Draw — the round is replayed")
		player.freeze()
		enemy.freeze()
		await _wait(2.0)
		_start_round()
		return
	_round_over(player if pr > er else enemy, "TIME")


func _round_over(winner: Fighter, text: String = "K.O.") -> void:
	phase = "end"
	touch.release_all()
	for c in get_tree().get_nodes_in_group("clones"):
		c.pop()
	player.statuses.erase("veil")
	enemy.statuses.erase("veil")
	Engine.time_scale = 0.35
	hud.banner(text)
	await _wait(1.2)
	Engine.time_scale = 1.0
	var loser := enemy if winner == player else player
	winner.celebrate()
	loser.freeze()
	await _wait(1.2)
	var wi := 0 if winner == player else 1
	hud.wins[wi] += 1
	if hud.wins[wi] >= hud.rounds_to_win:
		_match_over(winner == player)
	else:
		round_no += 1
		_start_round()


# ---------------------------------------------------------------- teams

func _next_alive_member() -> int:
	if _mode() == "single":
		return -1
	for i in team.size():
		var id: String = team[i]
		if i != active_idx and team_hp[id] != 0.0:
			return i
	return -1


func _replace_player(idx: int, keep_hp_of_old: bool) -> void:
	var old := player
	team_hp[team[active_idx]] = old.hp if keep_hp_of_old else 0.0
	active_idx = idx
	var np := _make_fighter(team[idx], PlayerController.new())
	var stored: float = team_hp[team[idx]]
	np.position = Vector2(clampf(old.position.x - old.facing * 160.0, stage.x, stage.y), ground_y)
	if stored > 0.0:
		np.hp = stored
		np.hp_changed.emit(np)
	np.opponent = enemy
	enemy.opponent = np
	player = np
	hud.left = np
	old.queue_free()
	_update_touch_labels()
	np.release()


func _relay_next() -> void:
	phase = "swap"
	var idx := _next_alive_member()
	hud.banner("%s FALLS" % player.display_name)
	await _wait(1.4)
	_replace_player(idx, false)
	hud.banner("%s ENTERS" % player.display_name)
	await _wait(0.8)
	hud.clear_banner()
	phase = "fight"


func _swap_member() -> void:
	var idx := _next_alive_member()
	if idx == -1 or not player.state in [Fighter.S.IDLE, Fighter.S.WALK]:
		return
	swap_cooldown = 5.0
	_replace_player(idx, true)
	hud.show_power(player, "TAG — " + player.display_name)


# ---------------------------------------------------------------- end / pause

func _match_over(victory: bool) -> void:
	phase = "over"
	AudioManager.sting("victory" if victory else "defeat")
	touch.visible = false
	_show_overlay(
		"VICTORY" if victory else "DEFEAT",
		"" if victory else "The story continues only after victory.",
		[["Continue", _continue]] if victory else [["Retry", _retry], ["Main Menu", _to_menu]],
		Color(1, 0.85, 0.4) if victory else Color(1, 0.35, 0.3))


func _continue() -> void:
	StoryManager.set_flag(fight.get("flag", ""))
	SceneRouter.go(fight.get("win_next", {"type": "menu"}))


func _retry() -> void:
	get_tree().paused = false
	SceneRouter.go({"type": "fight", "id": fight_id})


func _to_menu() -> void:
	get_tree().paused = false
	SceneRouter.go({"type": "menu"})


func _pause() -> void:
	if phase == "over" or get_tree().paused:
		return
	touch.release_all()
	get_tree().paused = true
	_show_overlay("PAUSED", "", [["Resume", _resume], ["Moves", _pause_briefing], ["Settings", _pause_settings],
		["Retry", _retry], ["Main Menu", _to_menu]], Color.WHITE)


func _show_briefing() -> Briefing:
	var b := Briefing.new()
	var pd := player.data.duplicate()
	var ed := enemy.data.duplicate()
	b.player = pd
	b.enemy = ed
	b.counters = fight.get("counters", [])
	ui_layer.add_child(b)
	return b


func _pause_briefing() -> void:
	overlay.visible = false
	await _show_briefing().closed
	overlay.visible = true


func _pause_settings() -> void:
	overlay.visible = false
	var s := SettingsPanel.new()
	ui_layer.add_child(s)
	await s.closed
	overlay.visible = true


func _resume() -> void:
	overlay.visible = false
	get_tree().paused = false


func _show_overlay(title: String, sub: String, actions: Array, col: Color) -> void:
	for c in overlay.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 26)
	overlay.add_child(vb)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 120)
	t.add_theme_color_override("font_color", col)
	vb.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_size_override("font_size", 38)
		s.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
		vb.add_child(s)
	for a in actions:
		var b := Button.new()
		b.text = a[0]
		b.custom_minimum_size = Vector2(460, 100)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 44)
		b.pressed.connect(a[1])
		vb.add_child(b)
	overlay.visible = true
