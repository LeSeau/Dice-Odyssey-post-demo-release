// The map as a sheet on the table (M2, H-189). One node (PaperBackground) draws the dark table,
// the sheet's soft shadow, and the parchment with torn, darkened edges. Everything is computed in
// MAP coordinates (the space room positions live in), so the torn edge stays put while the
// camera scrolls. Every uniform is seeded by map.gd::_sheet_material().
shader_type canvas_item;

uniform vec2 sprite_origin = vec2(0.0);   // PaperBackground.position
uniform vec2 sprite_scale = vec2(1.0);    // PaperBackground.scale
uniform vec4 sheet_rect = vec4(104.0, -1740.0, 1176.0, 668.0); // left, top, right, bottom
uniform vec3 tear_px = vec3(10.0, 4.0, 1.6);  // edge wander at three scales
uniform float nick_px = 12.0;                  // occasional notches torn into the edge
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec3 table_color : source_color = vec3(0.075, 0.09, 0.13);
uniform float burn_px = 26.0;
uniform float burn_noise_px = 18.0;
uniform float burn_strength = 0.33;
uniform float rim_px = 2.2;
uniform float rim_strength = 0.35;
uniform float shadow_px = 12.0;
uniform float shadow_drop = 7.0;
uniform float shadow_strength = 0.7;

varying vec2 map_pos;

void vertex() {
	map_pos = sprite_origin + VERTEX * sprite_scale;
}

float n1(float s, float row) {
	return texture(noise, vec2(s, row)).r - 0.5;
}

// How far the edge pushes outward at position s along it (px). Positive = more paper.
float tear(float s, float row) {
	float wander = 2.0 * (tear_px.x * n1(s * 0.0011, row)
			+ tear_px.y * n1(s * 0.0098, row + 0.23)
			+ tear_px.z * n1(s * 0.065, row + 0.47));
	float nick = max(0.0, texture(noise, vec2(s * 0.0042, row + 0.71)).r - 0.72) / 0.28;
	return wander - nick * nick_px;
}

// Signed distance to the torn sheet edge, px, positive inside.
float sheet_distance(vec2 p) {
	float left = sheet_rect.x - tear(p.y, 0.11);
	float right = sheet_rect.z + tear(p.y, 0.37);
	float top = sheet_rect.y - tear(p.x, 0.59);
	float bottom = sheet_rect.w + tear(p.x, 0.83);
	return min(min(p.x - left, right - p.x), min(p.y - top, bottom - p.y));
}

void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	float d = sheet_distance(map_pos);
	float aa = max(fwidth(d), 0.75);
	float inside = smoothstep(-aa, aa, d);

	float fine = texture(noise, map_pos / 160.0).r;
	float coarse = texture(noise, map_pos / 1400.0 + vec2(0.31, 0.17)).r;
	vec3 table = table_color * (0.86 + 0.18 * fine) * (0.85 + 0.3 * coarse);
	float shadow_d = sheet_distance(map_pos - vec2(0.0, shadow_drop));
	table *= 1.0 - shadow_strength * smoothstep(-shadow_px, shadow_px * 0.35, shadow_d);

	float burn_n = texture(noise, map_pos / 38.0 + vec2(0.7, 0.2)).r;
	float burn = 1.0 - smoothstep(0.0, burn_px + burn_noise_px * burn_n, d);
	float rim = 1.0 - smoothstep(0.0, rim_px, d);
	vec3 sheet = paper.rgb * (1.0 - burn_strength * burn) * (1.0 - rim_strength * rim);

	COLOR = vec4(mix(table, sheet, inside), 1.0);
}
