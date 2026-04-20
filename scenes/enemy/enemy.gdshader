shader_type canvas_item;

uniform float outline_thickness = 3.0; // Adjust for thicker/thinner borders
uniform vec4 outline_color = vec4(0.0, 0.0, 0.0, 1.0); // Black outline
uniform float anti_aliasing = 1.0; // Anti-aliasing strength

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    float alpha = tex_color.a;
    float outline = 0.0;
    vec2 texel_size = vec2(1.0) / vec2(textureSize(TEXTURE, 0)); // Size of a single texel


    // Iterate over the neighboring pixels to create the outline
    for (float x = -outline_thickness; x <= outline_thickness; x++) {
        for (float y = -outline_thickness; y <= outline_thickness; y++) {
            vec2 offset = vec2(x, y) * texel_size; // Offset by texel size
            outline = max(outline, texture(TEXTURE, UV + offset).a);
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
