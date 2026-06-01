shader_type canvas_item;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    // Top-half inner highlight
    float shine = smoothstep(0.5, 0.0, UV.y) * 0.10;
    COLOR = vec4(base.rgb + shine, base.a);
}