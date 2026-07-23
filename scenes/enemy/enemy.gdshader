shader_type canvas_item;

// Outline (hover/target highlight) + feet-planted idle sway (2026-07-23), one shader:
// the material swap dance in enemy.gd (hit-flash -> WHITE_SPRITE_MATERIAL -> back)
// restores a single material, so both effects must live on it together.
//
// The sway deforms the sprite in UV space instead of moving the quad: the feet stay
// welded to the ground shadow while the upper body leans (head trailing behind) and
// the chest rises on the inhale. All sway uniforms default to 0/off, so a material
// that only sets the outline params renders exactly like the old outline-only shader.
// Amplitude uniforms are in TEXTURE pixels - enemy.gd/player.gd convert from screen
// pixels by dividing by every scale between texture and screen.

uniform float outline_thickness = 3.0; // Adjust for thicker/thinner borders
uniform vec4 outline_color = vec4(0.0, 0.0, 0.0, 1.0); // Black outline
uniform float anti_aliasing = 1.0; // Anti-aliasing strength

uniform float sway_px = 0.0;      // horizontal lean at the very top of the sprite
uniform float sway_hz = 0.25;     // lean cycles per second
uniform float sway_curve = 1.7;   // height^curve weighting (higher = only the top moves)
uniform float head_px = 0.0;      // extra top-only follow-through
uniform float head_lag = 0.8;     // radians the head trails the body lean
uniform float breathe_px = 0.0;   // chest/head rise on inhale (feet never move)
uniform float breathe_hz = 0.5;
uniform float drift_px = 0.0;     // whole-body hover, floaters (Kraken) only
uniform float drift_hz = 0.25;
uniform float sway_phase = 0.0;   // per-enemy random time offset so groups never sync
uniform float sway_speed = 1.0;   // per-enemy speed jitter
// Bottom-anchored virtual margin: top/side sampling is inset by this many pixels so
// displaced content can't clip at the texture edge on tightly-trimmed art. v=1 (the
// feet line) maps exactly to itself, so grounding stays pixel-identical.
uniform float margin_px = 0.0;
// >= 0: overrides TIME, used by render harnesses for deterministic looping captures.
uniform float manual_time = -1.0;


vec2 sway_uv(vec2 raw_uv, vec2 tex_size) {
	vec2 m = margin_px / tex_size;
	vec2 uv;
	uv.x = (raw_uv.x - 0.5) * (1.0 + 2.0 * m.x) + 0.5;
	uv.y = 1.0 - (1.0 - raw_uv.y) * (1.0 + m.y);

	float t = manual_time >= 0.0 ? manual_time : TIME;
	t = t * sway_speed + sway_phase;
	float h = clamp(1.0 - uv.y, 0.0, 1.0); // 0 at the feet, 1 at the top

	float body = sin(TAU * sway_hz * t);
	float head = sin(TAU * sway_hz * t - head_lag);
	float dx = (sway_px * pow(h, sway_curve) * body + head_px * pow(h, 5.0) * head) / tex_size.x;

	// Inhale biased 0..1 so the rest pose = exhaled; everything above the waist rises
	// together and the lower body stretches to cover, feet planted.
	float inhale = sin(TAU * breathe_hz * t) * 0.5 + 0.5;
	float dy = (breathe_px * smoothstep(0.0, 0.6, h) * inhale + drift_px * sin(TAU * drift_hz * t + 0.4)) / tex_size.y;

	return vec2(uv.x - dx, uv.y + dy);
}

// Displaced sampling can land outside the texture; treat outside as transparent
// instead of letting edge-clamp smear the border pixels.
vec4 sample_tex(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 suv = sway_uv(UV, tex_size);
	vec4 tex_color = sample_tex(TEXTURE, suv);

	float alpha = tex_color.a;
	float outline = 0.0;
	vec2 texel_size = vec2(1.0) / tex_size; // Size of a single texel

	// Iterate over the neighboring pixels to create the outline - sampled through the
	// same swayed UV so the outline hugs the DISPLACED silhouette, not the rest pose.
	for (float x = -outline_thickness; x <= outline_thickness; x++) {
		for (float y = -outline_thickness; y <= outline_thickness; y++) {
			vec2 offset = vec2(x, y) * texel_size; // Offset by texel size
			outline = max(outline, sample_tex(TEXTURE, suv + offset).a);
		}
	}

	// Apply anti-aliasing by smoothly blending the outline edges
	outline = smoothstep(0.0, anti_aliasing, outline);

	// If the alpha is low and we are in the outline area, apply the outline color
	if (alpha < 0.1 && outline > 0.1) {
		COLOR = outline_color;
	} else {
		COLOR = tex_color;
	}
}
