shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.3, 0.6, 1.0, 1.0); // bluish glow
uniform float glow_radius : hint_range(1.0, 50.0) = 16.0;
uniform float glow_strength : hint_range(0.1, 5.0) = 1.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Get the original texture color
    vec4 original_color = texture(TEXTURE, UV);

    // Only apply the glow to non-transparent pixels of the dice
    if (original_color.a > 0.1) {
        // Create our glow
        vec2 size = vec2(glow_radius) / vec2(textureSize(TEXTURE, 0));
        float total_alpha = 0.0;

        // Sample neighboring pixels in a circular pattern
        for (float x = -glow_radius; x <= glow_radius; x += 1.0) {
            for (float y = -glow_radius; y <= glow_radius; y += 1.0) {
                vec2 offset = vec2(x, y) / TEXTURE_PIXEL_SIZE.xy;
                float dist = length(offset);

                if (dist <= glow_radius) {
                    vec2 sample_uv = UV + vec2(x, y) * TEXTURE_PIXEL_SIZE;
                    vec4 sample_color = texture(TEXTURE, sample_uv);
                    float factor = smoothstep(glow_radius, 0.0, dist) * glow_strength;
                    total_alpha += sample_color.a * factor;
                }
            }
        }

        // Mix the original color with the glow
        vec4 glow = glow_color * clamp(total_alpha, 0.0, 1.0);
        COLOR = original_color + glow * (1.0 - original_color.a);
    } else {
        // For transparent parts, check if they should receive the glow
        float total_alpha = 0.0;

        for (float x = -glow_radius; x <= glow_radius; x += 2.0) {
            for (float y = -glow_radius; y <= glow_radius; y += 2.0) {
                vec2 offset = vec2(x, y);
                float dist = length(offset);

                if (dist <= glow_radius) {
                    vec2 sample_uv = UV + vec2(x, y) * TEXTURE_PIXEL_SIZE;
                    // Make sure we don't sample outside the texture
                    if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
                        vec4 sample_color = texture(TEXTURE, sample_uv);
                        float factor = smoothstep(glow_radius, 0.0, dist) * glow_strength;
                        total_alpha += sample_color.a * factor;
                    }
                }
            }
        }

        COLOR = glow_color * clamp(total_alpha, 0.0, 1.0);
    }
}