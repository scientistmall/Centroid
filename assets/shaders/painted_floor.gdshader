// The arena floor, painted with the backdrop's own ground: each floor point takes the
// painting's colour at the spot it covers when seen from the starting camera, so floor and
// backdrop meet without a seam. It is still a real lit surface (shadows, firelight, powers).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D painting : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 cam = vec3(0.0, 2.27, 9.6);   // the starting camera
uniform float dist = 34.0;                  // painting plane at z = -dist
uniform float paint_w = 80.0;
uniform float paint_h = 32.0;
uniform float y_top = 21.0;
uniform float self_light = 0.45;            // keeps the painted look under dim lights

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = (cam.z + dist) / max(cam.z - wpos.z, 0.05);
	vec3 p = cam + (wpos - cam) * t;
	vec2 uv = vec2((p.x + paint_w * 0.5) / paint_w, (y_top - p.y) / paint_h);
	vec3 c = texture(painting, clamp(uv, vec2(0.002), vec2(0.998))).rgb;
	// nearer than the painting's bottom edge: tile its lowest band of ground instead of smearing it
	float past = smoothstep(0.93, 1.0, uv.y);
	if (past > 0.0) {
		vec2 m = abs(fract(vec2(wpos.x * 0.07, wpos.z * 0.12)) * 2.0 - 1.0);
		vec3 band = texture(painting, vec2(0.1 + m.x * 0.8, 0.84 + m.y * 0.12)).rgb;
		c = mix(c, band, past);
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
	EMISSION = c * self_light;
}
