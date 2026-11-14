class_name ImpactFrame
extends ColorRect
## The "impact frame" when a special lands: a flash in the attacker's colour, a radial
## blur out from the hit and a chromatic split, gone in about 0.2 s. It sits between the
## fight and the HUD and only renders while active.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center = vec2(0.5);
uniform float amount = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - center;
	vec3 acc = vec3(0.0);
	float ca = amount * 0.014;
	for (int i = 0; i < 8; i++) {
		float s = 1.0 - amount * 0.05 * float(i) / 7.0;
		vec2 u = center + dir * s;
		acc.r += texture(screen_tex, u + dir * ca).r;
		acc.g += texture(screen_tex, u).g;
		acc.b += texture(screen_tex, u - dir * ca).b;
	}
	acc /= 8.0;
	float l = dot(acc, vec3(0.299, 0.587, 0.114));
	vec3 hit = tint.rgb * (0.35 + 1.4 * l);
	float k = clamp(amount, 0.0, 1.0);
	COLOR = vec4(mix(acc, hit, k * k * 0.4) + tint.rgb * k * 0.06, 1.0);
}
"""

const TIME := 0.22

var _t := TIME
var _frames := 0   # the first two frames always show at full strength, even on a slow device
var _m: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_m = ShaderMaterial.new()
	_m.shader = sh
	material = _m
	visible = false


## `at` is the hit point in screen pixels.
func trigger(at: Vector2, col: Color) -> void:
	var vs := get_viewport_rect().size
	_m.set_shader_parameter("center", at / vs)
	_m.set_shader_parameter("tint", col)
	_t = 0.0
	_frames = 0
	_m.set_shader_parameter("amount", 1.0)
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_frames += 1
	if _frames <= 2:
		return
	_t += minf(delta, 1.0 / 30.0)
	var k := 1.0 - clampf(_t / TIME, 0.0, 1.0)
	_m.set_shader_parameter("amount", k * k)
	if _t >= TIME:
		visible = false
