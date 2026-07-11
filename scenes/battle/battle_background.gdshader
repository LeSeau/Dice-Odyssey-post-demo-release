shader_type canvas_item;

// Photographic grade for the combat background (scenes/battle/battle.tscn::Background).
// Replaces the old flat `modulate = 0.73` dim with tunable parameters: the same overall
// darkening, plus a saturation/contrast lift so the art doesn't go grey-washed from the dim,
// and a soft vignette that darkens the frame edges - focuses the eye on the fight and makes
// enemies/HUD pop for screenshots. All values editable on the material in the editor.

uniform float brightness : hint_range(0.4, 1.2) = 0.74;
uniform float saturation : hint_range(0.0, 2.0) = 1.08;
uniform float contrast : hint_range(0.5, 1.5) = 1.05;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_radius : hint_range(0.1, 1.2) = 0.55;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.55;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = tex.rgb;

	// Grade: saturation around luma, contrast around mid-grey, then exposure.
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= brightness;

	// Vignette: radial falloff from center, stretched slightly wider than tall so the
	// darkening hugs the 16:9 frame corners instead of clipping the top/bottom edges early.
	vec2 centered = UV - vec2(0.5);
	centered.x *= 1.15;
	float vig = smoothstep(vignette_radius, vignette_radius + vignette_softness, length(centered));
	c *= 1.0 - vig * vignette_strength;

	COLOR = vec4(c, tex.a);
}
