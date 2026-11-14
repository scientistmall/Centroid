// Live arena backdrop: the painted panorama, brought to life.
// The painting is a mesh pushed forward by its depth map (so it parallaxes as the fight
// camera moves); here, masks taken from the depth and the colours animate it:
//   sky (far, dark)       -> slow cloud drift, twinkling stars, a pulsing eclipse corona
//   warm bright pixels    -> flickering firelight with heat shimmer
//   saturated glows       -> crystals / magic light breathing
//   mid distance          -> drifting mist
// `flash` (set by ArenaLife) lights the whole sky for lightning.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform sampler2D painting : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float has_depth = 1.0;
uniform vec4 mist_color : source_color = vec4(0.6, 0.65, 0.75, 1.0);
uniform float mist = 0.16;
uniform vec4 flash_color : source_color = vec4(0.75, 0.6, 1.0, 1.0);
uniform float flash = 0.0;
uniform float fire = 1.0;       // how much warm pixels flicker (0 for arenas with no flames)
uniform float glow_pulse = 1.0; // crystal / magic light breathing

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float d = mix(0.5, texture(depth_map, uv).r, has_depth);
	float sky = (1.0 - smoothstep(0.04, 0.16, d)) * (1.0 - smoothstep(0.45, 0.75, uv.y));

	// clouds drift in the sky only
	vec2 flow = texture(noise_tex, uv * vec2(2.0, 1.2) + vec2(t * 0.006, t * 0.002)).rg - 0.5;
	uv += flow * 0.006 * sky;

	vec3 base = texture(painting, uv).rgb;
	float l = luma(base);
	vec3 col = base;

	// heat shimmer + flicker on fire-coloured light
	float warm = smoothstep(0.42, 0.85, l) * smoothstep(0.12, 0.32, base.r - base.b) * fire;
	if (warm > 0.001) {
		vec2 suv = uv + vec2(sin(uv.y * 260.0 + t * 9.0) * 0.0009, -0.0012 * abs(sin(t * 3.0 + uv.x * 40.0))) * warm;
		vec3 shim = texture(painting, suv).rgb;
		float fl = texture(noise_tex, uv * vec2(18.0, 9.0) + vec2(0.0, -t * 1.6)).r;
		float fl2 = 0.5 + 0.5 * sin(t * 11.0 + uv.x * 70.0);
		col = mix(col, shim, warm) * (1.0 + warm * (0.55 * (fl - 0.5) + 0.12 * fl2));
	}

	// crystals and magic light (bright, saturated, not fire) breathe slowly
	float mx = max(base.r, max(base.g, base.b));
	float mn = min(base.r, min(base.g, base.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float magic = smoothstep(0.35, 0.7, l) * smoothstep(0.45, 0.8, sat) * (1.0 - warm) * glow_pulse;
	float phase = texture(noise_tex, uv * 3.0).r * 6.28;
	col *= 1.0 + magic * 0.32 * sin(t * 1.6 + phase);

	// sky: the corona (bright, pale, in the sky) pulses; stars twinkle
	float pale = smoothstep(0.5, 0.85, l) * (1.0 - sat * 0.8);
	float tw = texture(noise_tex, uv * 40.0 + vec2(t * 0.05, 0.0)).r;
	col *= 1.0 + sky * pale * (0.18 * sin(t * 1.1) + 0.5 * (tw - 0.5));

	// drifting mist in the middle distance
	float band = smoothstep(0.08, 0.3, d) * (1.0 - smoothstep(0.55, 0.85, d));
	float m = texture(noise_tex, uv * vec2(1.6, 5.0) + vec2(t * 0.012, t * 0.003)).r;
	col = mix(col, mist_color.rgb, clamp(band * smoothstep(0.35, 0.8, m) * mist, 0.0, 0.6));

	// lightning lights up the sky and edges
	col += flash_color.rgb * flash * (sky * 0.9 + 0.12) * (0.4 + l);

	ALBEDO = col;
}
