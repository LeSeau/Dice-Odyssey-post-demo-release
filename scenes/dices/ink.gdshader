shader_type canvas_item;

// Parameters you can tweak in the editor
uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.1, 0.9);
uniform float flow_speed : hint_range(0.1, 2.0) = 0.5;
uniform float noise_scale : hint_range(1.0, 10.0) = 3.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.1;
uniform sampler2D noise_texture;

// Simple random function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Returns perlin-like noise
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    // Smooth interpolation
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

// Fractal Brownian Motion
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    // Add octaves of noise
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(st * frequency);
        st = st * 2.0 + 1.0;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

void fragment() {
    // Sample the original texture
    vec4 original = texture(TEXTURE, UV);

    // Create flowing ink effect
    vec2 motion = vec2(TIME * flow_speed, TIME * flow_speed * 0.5);
    float noise_value = fbm((UV + motion) * noise_scale);

    // Create ink mask with soft edges
    float ink_mask = smoothstep(0.3, 0.7, noise_value);

    // Mix original with ink based on mask
    vec4 result = mix(original, ink_color, ink_mask);

    // Add some variation to the ink
    float variation = fbm((UV - motion * 0.5) * noise_scale * 2.0) * 0.1;
    result.rgb += vec3(variation) * ink_color.rgb;

    // Apply edge effect
    float edge = smoothstep(edge_softness, 0.0, abs(noise_value - 0.5));
    result.a = max(result.a, edge * ink_color.a);

    COLOR = result;
}