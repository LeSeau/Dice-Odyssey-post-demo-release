shader_type canvas_item;

uniform vec4 magic_color : source_color = vec4(0.3, 0.6, 1.0, 0.7);
uniform vec4 accent_color : source_color = vec4(0.1, 0.3, 1.0, 0.5);
uniform float border_size : hint_range(0.01, 0.3) = 0.1;
uniform float border_softness : hint_range(0.01, 0.2) = 0.05;
uniform float power_intensity : hint_range(0.1, 2.0) = 1.0;
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float noise_scale : hint_range(1.0, 10.0) = 4.0;
uniform float square_roundness : hint_range(0.0, 1.0) = 0.3;
uniform float edge_fade_softness : hint_range(0.05, 0.5) = 0.2;
uniform sampler2D dice_texture : hint_default_white;
uniform bool use_texture_alpha = true;
// Driven live from GDScript alongside power_intensity/wave_speed as banked power grows -
// blends the glow toward a warm "hot/charged" highlight without erasing each die type's
// own base hue (capped well under 1.0 in the blend below so some base color always shows).
uniform float charge_heat : hint_range(0.0, 1.0) = 0.0;
// How far outward the glow fades out (was a hardcoded +0.15). Driven with charge_heat so
// the glow visibly widens as power grows WITHOUT moving where it starts (border_size, fixed -
// that's what keeps it anchored to the die's edge instead of drifting away as it grows).
uniform float glow_reach : hint_range(0.0, 0.5) = 0.15;

// Simplex noise function for natural waves
vec3 hash3(vec2 p) {
    vec3 q = vec3(dot(p, vec2(127.1, 311.7)),
                  dot(p, vec2(269.5, 183.3)),
                  dot(p, vec2(419.2, 371.9)));
    return fract(sin(q) * 43758.5453);
}

float noise(vec2 p) {
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

// Create a square border with controllable roundness
float square_border(vec2 uv, float size, float softness, float roundness) {
    // Distance to center
    vec2 centered = abs(uv - 0.5);

    // Squared distance (for square shape)
    float square_dist = max(centered.x, centered.y);

    // Circular distance (for round shape)
    float circle_dist = length(centered);

    // Mix between square and circle based on roundness parameter
    float dist = mix(square_dist, circle_dist, roundness);

    // Inner and outer edges of the border
    float outer_edge = 0.5 - size;
    float inner_edge = outer_edge + softness;

    // Create soft border
    return smoothstep(outer_edge, inner_edge, dist);
}

// Creates subtle square-ish waves
float soft_square_wave(vec2 uv, float time) {
    // Create subtle waves that follow the square shape but aren't too pronounced
    vec2 centered = uv - 0.5;
    vec2 abs_pos = abs(centered);

    // Subtle square-aligned distortion
    float x_wave = sin(abs_pos.x * 10.0 + time * 0.7) * 0.05;
    float y_wave = sin(abs_pos.y * 10.0 + time * 0.5) * 0.05;

    // Mix horizontal and vertical waves
    float wave = (x_wave + y_wave) * 0.5;

    // Make waves more even around the shape
    return wave * smoothstep(0.0, 0.4, max(abs_pos.x, abs_pos.y));
}

// Edge fade function to hide ColorRect boundaries
float edge_fade(vec2 uv, float softness) {
    // Calculate distance from each edge
    vec2 edge_dist = min(uv, 1.0 - uv);

    // Create smooth fade at the edges
    float fade_x = smoothstep(0.0, softness, edge_dist.x);
    float fade_y = smoothstep(0.0, softness, edge_dist.y);

    // Combine for overall edge fade
    return fade_x * fade_y;
}

// Additional noise for variable edge fade
float edge_noise(vec2 uv, float time) {
    // Create noise that will be used to vary the edge fade
    vec2 scaled_uv = uv * 3.0;
    float n1 = noise(scaled_uv + time * 0.1);
    float n2 = noise(scaled_uv * 2.0 - time * 0.15);

    return mix(n1, n2, 0.5);
}

void fragment() {
    // Sample the dice texture if provided
    float dice_alpha = 1.0;
    if (use_texture_alpha) {
        dice_alpha = texture(dice_texture, UV).a;
    }

    // Create square border mask with controllable roundness
    float border = square_border(UV, border_size, border_softness, square_roundness);

    // Create dynamic waves using noise
    float time_factor = TIME * wave_speed;

    // Sample noise at different frequencies and phases
    float noise1 = noise((UV - vec2(0.5)) * noise_scale + time_factor);
    float noise2 = noise((UV - vec2(0.5)) * noise_scale * 2.0 - time_factor * 0.7);
    float noise3 = noise((UV - vec2(0.5)) * noise_scale * 0.5 + time_factor * 1.3);

    // Add subtle square waves (not too emphasized)
    float sqr_wave = soft_square_wave(UV, TIME * wave_speed);

    // Combine noise and waves for interesting pattern
    float combined_effect = (noise1 * 0.4 + noise2 * 0.3 + noise3 * 0.2 + sqr_wave * 0.1);

    // Apply the effect at the border with falloff
    float power_effect = combined_effect * border;

    // Apply intensity
    power_effect *= power_intensity;

    // Mix the two colors based on noise for more visual interest
    vec4 final_color = mix(magic_color, accent_color, noise1 * 0.6);

    // Only show the effect outside the dice (based on texture alpha)
    float mask = 1.0;
    if (use_texture_alpha) {
        mask = 1.0 - dice_alpha;
    }

    // Create even falloff pattern
    vec2 centered = abs(UV - 0.5);
    float dist_sq = max(centered.x, centered.y);
    float dist_circle = length(centered);
    float dist = mix(dist_sq, dist_circle, square_roundness);

    // Smooth falloff away from the dice
    float falloff_start = 0.5 - border_size;
    float falloff_end = 0.5 + glow_reach;
    float outward_falloff = smoothstep(falloff_start, falloff_end, dist);

    // Create noise-influenced edge fade to hide ColorRect boundaries
    float edge_variation = edge_noise(UV, TIME * 0.2);
    float varying_softness = edge_fade_softness * (0.8 + edge_variation * 0.4);
    float boundary_fade = edge_fade(UV, varying_softness);

    // Add some subtle movement to the edge fade
    boundary_fade *= 0.8 + 0.2 * sin(TIME * 0.5 + UV.x * 5.0 + UV.y * 5.0);

    // Calculate final alpha with edge fade to hide boundaries
    float final_alpha = power_effect * final_color.a * mask * (1.0 - outward_falloff) * boundary_fade;

    // Blend toward a warm white-gold highlight as charge builds - "heating up" rather than
    // just getting brighter/bigger, while the 0.55 cap keeps each die's own hue recognizable.
    vec3 heat_highlight = vec3(1.0, 0.76, 0.22);
    final_color.rgb = mix(final_color.rgb, heat_highlight, charge_heat * 0.22);

    COLOR = vec4(final_color.rgb, final_alpha);
}