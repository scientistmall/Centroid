extends Node
## Music (crossfading, looping) and sound effects (pooled players).
## Music: res://assets/music/<name>.ogg   Effects: res://assets/sfx/<name>.ogg
## Every Button in the game automatically plays a click.

const MUSIC_DIR := "res://assets/music/%s.ogg"
const SFX_DIR := "res://assets/sfx/%s.ogg"
const POOL := 12
## Per-sound volume trims (dB) so loud synths sit right in the mix.
const TRIM := {"gravity": -6.0, "curse": -4.0, "ko": -2.0, "gong": -3.0, "ui_click": -6.0}

var current_music := ""
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _sting: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music.append(p)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	add_child(_sting)
	for i in POOL:
		var s := AudioStreamPlayer.new()
		s.bus = "SFX"
		add_child(s)
		_pool.append(s)
	apply_volumes()
	Settings.changed.connect(apply_volumes)
	get_tree().node_added.connect(_on_node_added)


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, Settings.music_volume)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, Settings.sfx_volume)))


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[path] = s
	return s


## Crossfades to a looping track. Same track = no restart.
func play_music(track: String, fade := 1.2) -> void:
	if track == current_music or track == "":
		return
	var stream := _load(MUSIC_DIR % track)
	if stream == null:
		push_warning("Missing music: %s" % track)
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	current_music = track
	var old := _music[_active]
	_active = 1 - _active
	var nw := _music[_active]
	nw.stream = stream
	nw.volume_db = -40.0
	nw.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(nw, "volume_db", 0.0, fade)
	t.tween_property(old, "volume_db", -40.0, fade)
	t.chain().tween_callback(old.stop)


func stop_music(fade := 1.0) -> void:
	current_music = ""
	for p in _music:
		if p.playing:
			var t := create_tween()
			t.tween_property(p, "volume_db", -40.0, fade)
			t.tween_callback(p.stop)


## One-shot musical sting (victory / defeat); ducks the current music.
func sting(track: String) -> void:
	var stream := _load(MUSIC_DIR % track)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = false
	stop_music(0.4)
	_sting.stream = stream
	_sting.play()


func sfx(sound: String, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	if sound == "":
		return
	var stream := _load(SFX_DIR % sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.volume_db = volume_db + TRIM.get(sound, 0.0)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("no_click"):
		node.pressed.connect(func(): sfx("ui_click", 0.0, 0.02))
