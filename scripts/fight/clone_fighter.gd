class_name CloneFighter
extends Fighter
## An illusion (Vaska's Mirror Double). Fights like its owner but deals no
## damage; any hit — or Clear Sight — makes it burst into mist.

var life := 6.0
var _popped := false


func _ready() -> void:
	add_to_group("clones")
	powers = []           # illusions can't use powers
	max_hp = 1.0
	hp = 1.0


func damage_mult() -> float:
	return 0.0


func is_veiled() -> bool:
	return false


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or opponent == null or not opponent.is_alive():
		pop()
		return
	super._physics_process(delta)
	modulate.a = 0.5 + 0.12 * sin(clock * 9.0)


func receive_hit(_attacker: Fighter, _m: Dictionary) -> String:
	pop()
	return "miss"


func pop() -> void:
	if _popped:
		return
	_popped = true
	if effects_parent:
		var b := BurstFx.new()
		b.radius = 140.0
		b.color = Color(0.8, 0.85, 0.95)
		b.position = position + Vector2(0, -140)
		effects_parent.add_child(b)
	queue_free()
