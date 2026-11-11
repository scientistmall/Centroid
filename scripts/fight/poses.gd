class_name Poses
extends RefCounted
## Pose library for the procedural silhouette fighters.
##
## Angles are in degrees. A limb angle of 0 points straight down; positive
## values rotate it forward (toward the direction the fighter faces).
## Lower limbs (la_* forearm, sh_* shin) are relative to their upper limb.
## `lean` tilts the torso forward, `wpn` is the weapon's absolute angle
## (0 = down, 90 = forward, 180 = straight up), `rot` rotates the whole body
## (used for knockdowns).

const BASE := {
	"lean": 8.0, "rot": 0.0,
	"ua_f": 35.0, "la_f": 70.0, "ua_b": -15.0, "la_b": 85.0,
	"th_f": 24.0, "sh_f": -18.0, "th_b": -22.0, "sh_b": -12.0,
	"wpn": 140.0, "wpn_b": 120.0,
}

const LIB := {
	"idle": {},
	"walk": {},
	"air": {"th_f": 70.0, "sh_f": -95.0, "th_b": 10.0, "sh_b": -80.0, "ua_f": 70.0, "la_f": 50.0, "ua_b": 40.0, "wpn": 120.0},
	"block": {"lean": 2.0, "ua_f": 70.0, "la_f": 105.0, "ua_b": 55.0, "la_b": 110.0, "wpn": 172.0, "wpn_b": 172.0, "th_f": 30.0, "th_b": -28.0},
	"hurt": {"lean": -22.0, "ua_f": -35.0, "la_f": 35.0, "ua_b": -45.0, "la_b": 25.0, "wpn": 40.0, "th_f": 10.0, "sh_f": -25.0, "th_b": -30.0},
	"ko": {"rot": -88.0, "lean": -5.0, "ua_f": 160.0, "la_f": 10.0, "ua_b": 140.0, "la_b": 10.0, "th_f": 15.0, "sh_f": -10.0, "th_b": -5.0, "sh_b": -20.0, "wpn": 200.0},
	"win": {"lean": -2.0, "ua_f": 165.0, "la_f": 10.0, "ua_b": -5.0, "la_b": 60.0, "wpn": 180.0, "th_f": 12.0, "sh_f": 0.0, "th_b": -12.0, "sh_b": 0.0},

	# attack windup / strike pairs
	"slash_w": {"lean": 0.0, "ua_f": 145.0, "la_f": 40.0, "wpn": 210.0},
	"slash_s": {"lean": 20.0, "ua_f": 75.0, "la_f": 10.0, "wpn": 70.0, "th_f": 40.0, "sh_f": -10.0},
	"thrust_w": {"lean": 0.0, "ua_f": 15.0, "la_f": 115.0, "wpn": 95.0},
	"thrust_s": {"lean": 22.0, "ua_f": 88.0, "la_f": 4.0, "wpn": 90.0, "th_f": 50.0, "sh_f": -15.0, "th_b": -35.0},
	"overhead_w": {"lean": -12.0, "ua_f": 172.0, "la_f": 15.0, "ua_b": 150.0, "wpn": 195.0},
	"overhead_s": {"lean": 32.0, "ua_f": 65.0, "la_f": 0.0, "ua_b": 50.0, "wpn": 45.0, "th_f": 55.0, "sh_f": -50.0, "th_b": -40.0},
	"rising_w": {"lean": 25.0, "ua_f": 15.0, "la_f": 15.0, "wpn": 25.0, "th_f": 50.0, "sh_f": -60.0},
	"rising_s": {"lean": -8.0, "ua_f": 165.0, "la_f": 5.0, "wpn": 175.0, "th_f": 20.0, "sh_f": 0.0},
	"kick_w": {"lean": -10.0, "th_f": 75.0, "sh_f": -110.0},
	"kick_s": {"lean": -20.0, "th_f": 98.0, "sh_f": -2.0, "ua_f": 20.0, "la_f": 90.0},
	"sweep_w": {"lean": 30.0, "th_f": 60.0, "sh_f": -100.0, "th_b": -40.0, "sh_b": -100.0},
	"sweep_s": {"lean": 38.0, "th_f": 85.0, "sh_f": -5.0, "th_b": -30.0, "sh_b": -110.0, "wpn": 60.0},
	"cast_w": {"lean": -5.0, "ua_f": 25.0, "la_f": 125.0, "ua_b": 60.0, "la_b": 90.0},
	"cast_s": {"lean": 15.0, "ua_f": 92.0, "la_f": 2.0, "ua_b": 80.0, "la_b": 10.0, "wpn": 92.0, "th_f": 40.0, "th_b": -35.0},
	"dash_w": {"lean": 30.0, "ua_f": 20.0, "la_f": 60.0, "wpn": 20.0, "th_f": 55.0, "sh_f": -70.0, "th_b": -30.0, "sh_b": -40.0},
	"dash_s": {"lean": 45.0, "ua_f": 100.0, "la_f": 0.0, "wpn": 100.0, "th_f": 65.0, "sh_f": -30.0, "th_b": -55.0, "sh_b": -40.0},
	"burst_w": {"lean": 30.0, "ua_f": 20.0, "la_f": 20.0, "ua_b": 30.0, "wpn": 10.0, "th_f": 55.0, "sh_f": -80.0, "th_b": -40.0, "sh_b": -70.0},
	"burst_s": {"lean": -10.0, "ua_f": 175.0, "la_f": 0.0, "ua_b": 150.0, "la_b": 0.0, "wpn": 190.0, "th_f": 40.0, "sh_f": 0.0, "th_b": -40.0, "sh_b": 0.0},
	"air_w": {"th_f": 70.0, "sh_f": -95.0, "th_b": 10.0, "sh_b": -80.0, "ua_f": 160.0, "la_f": 30.0, "wpn": 200.0},
	"air_s": {"th_f": 70.0, "sh_f": -95.0, "th_b": 10.0, "sh_b": -80.0, "lean": 25.0, "ua_f": 60.0, "la_f": 0.0, "wpn": 30.0},
}


static func get_pose(pose_name: String) -> Dictionary:
	var p := BASE.duplicate()
	var over: Dictionary = LIB.get(pose_name, {})
	for k in over:
		p[k] = over[k]
	return p


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	t = clampf(t, 0.0, 1.0)
	for k in a:
		out[k] = lerpf(a[k], b.get(k, a[k]), t)
	return out


static func walk_cycle(clock: float, speed_sign: float) -> Dictionary:
	var p := get_pose("idle")
	var s := sin(clock * 11.0) * speed_sign
	p["th_f"] = 15.0 + 30.0 * s
	p["th_b"] = -15.0 - 30.0 * s
	p["sh_f"] = -25.0 - 20.0 * maxf(0.0, -s)
	p["sh_b"] = -25.0 - 20.0 * maxf(0.0, s)
	return p


static func idle_breath(clock: float) -> Dictionary:
	var p := get_pose("idle")
	var b := sin(clock * 3.0)
	p["lean"] += b * 1.5
	p["ua_f"] += b * 3.0
	p["th_f"] += b * 1.5
	p["th_b"] -= b * 1.5
	return p
