// Soft edges for the event picture (E1, H-189): the picture fades into its own blurred
// backdrop instead of sitting in a gold frame. Used on a TextureRect with STRETCH_SCALE, so
// UV spans the whole rect. feather_px = fade width in px for left, top, right, bottom.
// Both uniforms are seeded at creation by event_look.gd (an unset uniform reads its default,
// never null here, but the sizes must match the rect the picture was fitted to).
shader_type canvas_item;

uniform vec2 rect_px = vec2(700.0, 470.0);
uniform vec4 feather_px = vec4(34.0, 34.0, 90.0, 34.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = UV * rect_px;
	float m = smoothstep(0.0, max(feather_px.x, 0.001), p.x)
			* smoothstep(0.0, max(feather_px.z, 0.001), rect_px.x - p.x)
			* smoothstep(0.0, max(feather_px.y, 0.001), p.y)
			* smoothstep(0.0, max(feather_px.w, 0.001), rect_px.y - p.y);
	// COLOR arrives as the node's modulate: keep it, or self_modulate would do nothing.
	COLOR = tex * COLOR;
	COLOR.a *= m;
}
