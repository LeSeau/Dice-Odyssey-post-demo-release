shader_type canvas_item;

// Exhaust burn (2026-09-23), drawn on a TextureRect that shows the card through a SubViewport
// (see CardUI._burn_away). The card burns from its border inward along ragged noise tongues:
// just ahead of the flame it scorches dark, right at the edge it glows ember, behind the edge it
// is gone. `progress` 0 -> 1 takes the whole card.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ember_color : source_color = vec4(1.0, 0.55, 0.18, 1.0);
// The card's own rect inside the padded texture (the padding holds its glow and shadow).
uniform vec2 card_uv_min = vec2(0.08, 0.06);
uniform vec2 card_uv_max = vec2(0.92, 0.94);
uniform float rim_width = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 cu = (UV - card_uv_min) / (card_uv_max - card_uv_min);
	// Distance to the card's nearest edge: 0 on the border, 0.5 at the centre, negative outside.
	float edge = min(min(cu.x, 1.0 - cu.x), min(cu.y, 1.0 - cu.y));
	// Low values burn first: the border goes, then noise tongues eat inward.
	float field = clamp(edge * 2.0, -0.2, 1.0) * 0.62 + fbm(cu * vec2(4.0, 6.0)) * 0.38;
	float d = field - (progress * 1.15 - 0.05);
	float alive = step(0.0, d);
	float rim = (1.0 - smoothstep(0.0, rim_width, d)) * alive;
	float scorch = (1.0 - smoothstep(0.0, rim_width * 4.0, d)) * alive;
	vec3 col = c.rgb * (1.0 - 0.6 * scorch);
	col = mix(col, ember_color.rgb * 1.6 + vec3(0.25), rim);
	COLOR = vec4(col, c.a * alive);
}
