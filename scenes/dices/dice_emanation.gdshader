shader_type canvas_item;
// LIGHT, not stuff (Julien's "alive light" ruling, 2026-07-24, after two rounds against
// substance-looking versions): additive blending means this layer can only ever ADD
// brightness - it is physically incapable of drawing dark bodies or opaque shapes, so it
// always reads as radiance coming off the die, like the old ring glow did.
render_mode blend_add;

// "Alive light" layer for the active die (STS2-Necrobinder-inspired energy, 3rd rework).
// A tight, soft-edged halo hugging the die's silhouette - same material feel as the old
// ring glow - whose brightness is streamed through by rising flame-licks of light. The
// organic/unpredictable quality lives in the BRIGHTNESS patterns (and the soft contour
// they imply), never in defined shapes: no thresholds, no rims, no outlines.
//
// Renders on the oversized Emanation ColorRect (first child of dice.tscn, so it draws
// UNDER the die/panel/aura) and composes WITH the ring glow (dice_glow.gdshader).
//
// Coordinates: everything below works in die-centered PIXELS (+y down), derived from
// rect_size + die_center_uv, so resizing/moving the ColorRect only needs those uniforms
// retuned, never the shape math.
//
// HUD clearance: the dice-type slot row sits ~11px above the die (battle.tscn), and this
// rect draws OVER it (ActiveDice comes later in battle.tscn's tree). Light directly above
// the die is hard-faded at the row's bottom edge (ROW_* consts below); only the side
// channels left/right of the row may glow higher. Keeps the row fully readable.

uniform vec4 accent_color : source_color = vec4(0.30, 0.60, 1.00, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.10, 0.45, 1.0);
// 0 = resting wisp, 1 = fully charged rage. Driven from _update_dice_aura_charge().
uniform float charge : hint_range(0.0, 1.0) = 0.0;
// Same warm-gold blend the ring uses, so both layers heat up together.
uniform float charge_heat : hint_range(0.0, 1.0) = 0.0;
// Transient flare on roll landing (spiked to 1, decays in code). Pushes energy past
// the sustained charge level for a beat.
uniform float surge : hint_range(0.0, 1.0) = 0.0;
uniform float base_speed = 1.0;
uniform float master_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec2 rect_size = vec2(320.0, 300.0);
uniform vec2 die_center_uv = vec2(0.5, 0.6);
uniform vec2 die_half_px = vec2(74.0, 74.0);
uniform float die_corner_px = 16.0;

// Slot-row clearance, in die-centered px: the row spans the die's width and its bottom
// edge sits ~11px above the die top (die top = -74 locally, row bottom ~= -85).
const float ROW_HALF_WIDTH = 92.0;
const float ROW_BOTTOM_Y = -85.0;
const float ROW_FADE_PX = 12.0;

// Same value-noise family as dice_glow.gdshader, so the two layers churn in a
// consistent style.
vec3 hash3(vec2 p) {
	vec3 q = vec3(dot(p, vec2(127.1, 311.7)),
				  dot(p, vec2(269.5, 183.3)),
				  dot(p, vec2(419.2, 371.9)));
	return fract(sin(q) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float n = mix(
		mix(dot(hash3(i + vec2(0.0, 0.0)), vec3(f - vec2(0.0, 0.0), 1.0)),
			dot(hash3(i + vec2(1.0, 0.0)), vec3(f - vec2(1.0, 0.0), 1.0)), u.x),
		mix(dot(hash3(i + vec2(0.0, 1.0)), vec3(f - vec2(0.0, 1.0), 1.0)),
			dot(hash3(i + vec2(1.0, 1.0)), vec3(f - vec2(1.0, 1.0), 1.0)), u.x), u.y);
	return 0.5 + 0.5 * n;
}

// Signed distance to the die's rounded-square silhouette (px, positive outside).
float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - die_center_uv) * rect_size;
	float d = sd_round_box(p, die_half_px, die_corner_px);

	// Energy level: sustained charge plus the transient landing surge. Late-blooming
	// growth (pow) keeps low charge TIGHT - the tall reach only arrives at high power
	// (~12+ banked, i.e. charge ~0.7 on the shared curve).
	float energy = clamp(charge + surge * 0.35, 0.0, 1.3);
	float level = clamp(energy, 0.0, 1.0);
	float growth = pow(level, 1.6);
	float reach = mix(14.0, 44.0, growth) + 8.0 * max(energy - 1.0, 0.0);

	// Direction budget: the upward bias itself grows with charge, so a low-power halo
	// hugs the die evenly (never reaching the slot row) while a charged one streams
	// upward. Near-nothing below (the ROLL button lives there).
	vec2 dirn = p / max(length(p), 0.001);
	float up_f = clamp(-dirn.y, 0.0, 1.0);
	float down_f = clamp(dirn.y, 0.0, 1.0);
	float dir_budget = 0.60 + (0.20 + 0.45 * growth) * up_f * up_f - 0.45 * down_f;

	// Rising, churning noise field: sampling y grows over time so the pattern climbs,
	// a slow sine sways it laterally, and a low-frequency warp billows it sideways.
	// Features taller than wide so the bright licks read as rising tongues of light.
	float spd = base_speed * (0.85 + 0.85 * energy);
	float t = TIME * spd;
	vec2 q = p * vec2(0.050, 0.027);
	q.y += t * 1.5;
	q.x += sin(p.y * 0.02 + TIME * 0.6) * 0.22;
	float w = vnoise(q * 0.5 - vec2(0.0, t * 0.30));
	q.x += (w - 0.5) * 1.1;
	float n = vnoise(q) * 0.60
		+ vnoise(q * 2.07 + vec2(0.0, t * 0.50)) * 0.28
		+ vnoise(q * 4.13 - vec2(t * 0.15, t * 0.70)) * 0.12;

	// The halo: soft feathered falloff hugging the edge (the old glow's footprint).
	// pow() concentrates it near the die and feathers the tail - no boundary anywhere.
	float halo = 1.0 - smoothstep(-2.0, max(reach * dir_budget, 6.0), d);
	halo = pow(halo, 1.7);

	// Flame-licks of BRIGHTNESS, not shape: pow() on the raw noise turns it into bright
	// streaks over a soft base. Sparse crisp licks at rest, denser fire-light charged.
	float streaks = pow(clamp(n, 0.0, 1.0), mix(2.35, 1.8, growth));

	// Keep the die face clean and the slot row readable.
	float inside_cut = smoothstep(-4.0, 6.0, d);
	float row_side = step(abs(p.x), ROW_HALF_WIDTH);
	float allowed = smoothstep(ROW_BOTTOM_Y - ROW_FADE_PX, ROW_BOTTOM_Y, p.y);
	float row_cut = mix(1.0, allowed, row_side);

	// Energy gain deliberately front-loaded (0.74 base): low/mid power is clearly visible
	// (Julien's call after approving the alive-light look), full charge tops out the same.
	// Intensity scales here - SIZE stays governed by the late-blooming growth curve above.
	float lum = halo * (0.27 + 1.25 * streaks) * (0.74 + 0.26 * energy);
	lum *= inside_cut * row_cut * master_alpha;

	// Accent-colored light, whitening slightly where streaks peak near the die (the
	// energy source), with a whisper of the deep hue at the tips for color depth;
	// charge_heat pulls toward the same warm gold as the ring glow.
	float root_glow = 1.0 - smoothstep(0.0, 20.0, d);
	vec3 col = mix(accent_color.rgb, vec3(1.0), (0.18 + 0.30 * streaks) * root_glow);
	col = mix(col, deep_color.rgb, clamp(d / max(reach, 6.0), 0.0, 1.0) * 0.25);
	vec3 heat = vec3(1.0, 0.76, 0.22);
	col = mix(col, heat, charge_heat * 0.35);

	COLOR = vec4(col, clamp(lum, 0.0, 0.8));
}
