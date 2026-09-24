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
// Band ripple (2026-09-23): a travelling wave confined to one rectangle of the sprite, so parts
// that should move on their own (tentacles, snake hair, a flame mane) do, while the body leans
// as one piece above. ripple_band = (x_lo, x_hi, h_lo, h_hi) in texture UV, with h measured
// like everywhere else here: 0 at the feet, 1 at the top. The weight is 0 where the band meets
// the body and grows toward the free end, so there is never a seam. Off (0) by default.
uniform float ripple_px = 0.0;    // horizontal displacement at the free end, TEXTURE pixels
uniform float ripple_hz = 0.5;
uniform float ripple_waves = 1.0; // wavelengths along the band
uniform vec4 ripple_band = vec4(0.0, 1.0, 0.0, 0.4);
uniform float ripple_free_top = 0.0; // 0: free end at the band's bottom (tentacles), 1: at its top (hair, flames)
// Additive body flash (2026-09-23) for attack/guard/buff beats. modulate cannot do this job:
// fragment() below overwrites COLOR with the raw texture, so it discards modulate entirely.
// Weighted by the texel's alpha so the outline and transparent pixels never light up.
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount = 0.0;
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

	if (ripple_px > 0.0) {
		float band_h = max(ripple_band.w - ripple_band.z, 0.001);
		float s = clamp((h - ripple_band.z) / band_h, 0.0, 1.0);
		// 0 where the band is attached to the body, 1 at the free end
		float free_s = mix(1.0 - s, s, ripple_free_top);
		float mx = smoothstep(ripple_band.x - 0.05, ripple_band.x + 0.05, uv.x)
				* (1.0 - smoothstep(ripple_band.y - 0.05, ripple_band.y + 0.05, uv.x));
		float w = pow(free_s, 1.5) * mx;
		// The wave travels toward the free end, like a tentacle curling or a flame licking up.
		dx += ripple_px * w * sin(TAU * ripple_hz * t - free_s * TAU * ripple_waves) / tex_size.x;
	}

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
		COLOR.rgb += flash_color.rgb * flash_amount * tex_color.a;
	}
}
