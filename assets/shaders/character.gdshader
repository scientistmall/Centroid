shader_type spatial;
// Fighter material: texture, soft rim light, additive hit flash, and secondary motion.
// Secondary motion: vertex colour R = cloth flex (coat tails, skirts), G = hair flex
// (made by tools/models/fix_rig.gd). Model3D drives `sway` from a damped spring that lags
// behind the fighter's movement, so coats and hair trail, overshoot and settle.
// VERTEX here is already skinned (model space), so the sway rides on top of the animation.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_flex = false;
uniform vec3 sway = vec3(0.0);        // model-space offset at full flex
uniform float wind = 0.0;             // model-space flutter amplitude
uniform float time_s = 0.0;
uniform float model_height = 1.0;     // model-space height, scales the flutter pattern
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float flash = 0.0;

void vertex() {
	if (use_flex) {
		float cloth = COLOR.r;
		float hair = COLOR.g;
		float f = cloth * cloth + hair * 0.55;
		if (f > 0.001) {
			float k = 1.0 / max(model_height, 1e-6);
			float n1 = sin(time_s * 3.3 + VERTEX.y * k * 11.0 + VERTEX.x * k * 6.0);
			float n2 = sin(time_s * 4.7 + VERTEX.y * k * 7.0 - VERTEX.z * k * 9.0);
			VERTEX += sway * f + vec3(n1, 0.25 * n2, n2) * wind * f;
		}
	}
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = t.rgb;
	ROUGHNESS = 0.72;
	METALLIC = 0.0;
	SPECULAR = 0.4;
	RIM = rim_amount;
	RIM_TINT = 0.55;
	EMISSION = flash_color * flash;
}
