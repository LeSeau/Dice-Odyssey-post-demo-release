shader_type canvas_item;
render_mode blend_add;

// The charged die (2026-09-25, H-184): light INSIDE the die, growing with the banked Power.
// Drawn by the FaceLight ColorRect, an additive layer laid over DiceDisplay. The face itself
// is never redrawn, so every modulate on the die (dormant dim, landing flashes, the dud's
// dim) dims or brightens this light along with it.
//   veins - the lighter lines already painted on each face (cracks, bevel) glow, with light
//           flowing through them, and flash on landing (vein_surge).
//   pips  - a halo around each pip that follows the banked Power, plus a tight landing flash
//           that stays on the pip so neighbouring pips never melt into one blob.
// The face is read from face_tex, kept in sync with DiceDisplay.texture by dice.gd.
// Tuned in .claude/worktrees/roll-glow-orb-proposals/ (debug_proto_die_face.gdshader, flat-face
// branch only: the tumble that shader also drew was not kept).

// Mipmapped like the face itself (DicePalette.crisp_face), so the vein mask never shimmers.
uniform sampler2D face_tex : filter_linear_mipmap;
// Median body colour of this die's art. The vein mask is "brighter than the body and
// saturated, not a cream pip", so each type needs its own body (dice.gd VEIN_BODY).
uniform vec3 vein_body = vec3(0.004, 0.231, 0.545);
uniform vec4 vein_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform float vein_amount : hint_range(0.0, 2.0) = 0.0;
uniform float vein_surge : hint_range(0.0, 3.0) = 0.0;
uniform float vein_speed = 1.4;
// Pip centres in face UV, from dice.gd's pip scan of the current face.
uniform vec2 pip_pos[12];
uniform int pip_count = 0;
uniform float pip_radius = 0.085;
uniform float pip_glow : hint_range(0.0, 4.0) = 0.0;
uniform float pip_flash : hint_range(0.0, 4.0) = 0.0;
uniform vec4 pip_color : source_color = vec4(0.62, 0.8, 1.0, 1.0);

float vein_mask(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float body_l = dot(vein_body, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float pip = smoothstep(0.72, 0.84, lum) * (1.0 - smoothstep(0.10, 0.22, sat));
	return smoothstep(0.03, 0.13, lum - body_l) * smoothstep(0.10, 0.24, sat) * (1.0 - pip);
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 face = texture(face_tex, UV);
	vec3 light = vec3(0.0);
	if (vein_amount + vein_surge > 0.001) {
		// A slow travelling wave warped by noise, so it reads as energy moving inside the
		// die, not a blink.
		float flow = 0.55 + 0.45 * sin(UV.x * 7.0 + UV.y * 5.0 - TIME * vein_speed * 3.0
				+ vnoise(UV * 6.0 + TIME * 0.4) * 5.0);
		light += vein_color.rgb * vein_mask(face.rgb) * (vein_amount * flow + vein_surge);
	}
	if (pip_count > 0 && pip_glow + pip_flash > 0.001) {
		float g = 0.0;
		float gf = 0.0;
		for (int i = 0; i < 12; i++) {
			if (i >= pip_count) {
				break;
			}
			float d = length(UV - pip_pos[i]) / pip_radius;
			// Halo: peaks just outside the pip's edge (d ~ 1), gone by ~2.4 radii.
			g += exp(-pow(max(d - 0.55, 0.0) * 1.35, 2.0));
			// Landing flash: the pip plus a thin rim, gone by ~1.5 radii.
			gf += exp(-pow(max(d - 0.75, 0.0) * 2.6, 2.0));
		}
		light += pip_color.rgb * min(g, 1.6) * pip_glow * 0.55;
		light += mix(pip_color.rgb, vec3(1.0), 0.4) * min(gf, 1.0) * pip_flash * 0.5;
	}
	// COLOR arrives as the inherited modulate (a ColorRect has a white texture).
	COLOR = vec4(light * face.a, 1.0) * COLOR;
}
