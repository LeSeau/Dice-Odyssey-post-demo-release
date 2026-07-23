shader_type canvas_item;

// Feet-planted idle sway (preview build, 2026-07-23).
// Deforms the sprite in UV space instead of moving the whole quad: the feet stay
// welded to the ground line while the upper body leans/breathes. Driven by a manual
// clock uniform (anim_time) so the capture harness renders deterministic, perfectly
// looping GIF frames; an in-game version would run off TIME + a per-enemy phase.
//
// All *_px uniforms are in TEXTURE pixels - the harness converts from screen pixels
// by dividing by the sprite's scale before setting them.

uniform float anim_time = 0.0;
uniform float loop_seconds = 4.0;
uniform vec2 tex_size = vec2(512.0, 512.0);
// Virtual transparent margin: sampling is zoomed out by this many pixels so displaced
// content never hits the texture edge and clips (most enemy art is trimmed tight).
uniform float margin_px = 6.0;

uniform float sway_px = 4.0;        // horizontal lean at the very top of the sprite
uniform float sway_cycles = 1.0;    // full lean cycles per loop
uniform float sway_curve = 1.7;     // height^curve weighting (higher = only the top moves)
uniform float head_px = 2.0;        // extra top-only follow-through
uniform float head_lag = 0.8;       // radians the head trails the body lean
uniform float breathe_px = 3.0;     // chest/head rise on inhale (feet never move)
uniform float breathe_cycles = 2.0;
uniform float drift_px = 0.0;       // whole-body hover, floaters only
uniform float drift_cycles = 1.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 m = margin_px / tex_size;
	vec2 uv = (UV - 0.5) * (1.0 + 2.0 * m) + 0.5;

	float t = anim_time / loop_seconds; // 0..1 over one loop
	float h = clamp(1.0 - uv.y, 0.0, 1.0); // 0 at the feet, 1 at the top

	// Horizontal lean, weighted toward the top, with the head trailing slightly so the
	// motion reads organic instead of a rigid shear.
	float body = sin(TAU * sway_cycles * t);
	float head = sin(TAU * sway_cycles * t - head_lag);
	float dx = (sway_px * pow(h, sway_curve) * body + head_px * pow(h, 5.0) * head) / tex_size.x;

	// Breathing: everything above the waist rises together on the inhale (0..1 biased so
	// rest pose = exhaled), lower body stretches to cover, feet stay planted.
	float inhale = sin(TAU * breathe_cycles * t) * 0.5 + 0.5;
	float dy_breathe = breathe_px * smoothstep(0.0, 0.6, h) * inhale;

	// Hover drift for floaters: the whole body, feet included, slowly rides up and down.
	float dy_drift = drift_px * sin(TAU * drift_cycles * t + 0.4);

	vec2 suv = vec2(uv.x - dx, uv.y + (dy_breathe + dy_drift) / tex_size.y);
	if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, suv) * v_modulate;
	}
}
