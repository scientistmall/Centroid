extends Node
## Prints how far each two-handed fighter's left fist is from its weapon grip target.
func _ready() -> void:
	SceneRouter.current = {"type": "fight", "id": "fight01", "no_briefing": true}
	var a = load("res://scenes/fight/arena.tscn").instantiate()
	add_child(a)
	for i in 400:
		await get_tree().physics_frame
		if a.phase == "fight":
			break
	for i in 60:
		await get_tree().process_frame
	for f in [a.player, a.enemy]:
		var m = a._puppets.get(f)
		if m == null or not m._two_handed:
			print(f.char_id, " not two-handed")
			continue
		var sk: Skeleton3D = m._sk
		var grip: Vector3 = sk.get_bone_global_pose(sk.find_bone("RightHand")) * (m._w_hand_xf * m._lgrip)
		var kn := sk.find_bone("LeftMiddleProximal")
		var hd := sk.find_bone("LeftHand")
		var fist: Vector3 = sk.get_bone_global_pose(hd).origin + (sk.get_bone_global_pose(kn).origin - sk.get_bone_global_pose(hd).origin) * 0.75
		# distance of each fist centre from the weapon's hilt line
		var wx: Transform3D = m._weapon.transform
		var ax: Vector3 = wx.basis.y.normalized()
		var out := []
		for side in ["Right", "Left"]:
			var p: Vector3 = m._fist(side) - wx.origin
			out.append(snappedf((p - ax * p.dot(ax)).length(), 0.001))
		print(f.char_id, " hold ", m._hold, " two ", snappedf(m._two_w, 0.01), " fist-to-hilt-line R,L ", out)
	get_tree().quit()
