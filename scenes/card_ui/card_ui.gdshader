shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.0, 0.6);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float glow_size : hint_range(0.0, 10.0) = 2.0;

// Enhanced pulse effect parameters
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
uniform float pulse_min : hint_range(0.1, 0.9) = 0.3;
uniform float pulse_max : hint_range(1.0, 3.0) = 2.0;

void fragment() {
    // Original texture color
    vec4 texture_color = texture(TEXTURE, UV);

    // Calculate more noticeable pulsating effect
    float pulse = mix(pulse_min, pulse_max, 0.5 + 0.5 * sin(TIME * pulse_speed * 3.14159));

    // Calculate glow effect
    vec4 glow = vec4(0.0);
    for(float x = -glow_size; x <= glow_size; x += 1.0) {
        for(float y = -glow_size; y <= glow_size; y += 1.0) {
            vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
            glow += texture(TEXTURE, UV + offset).a * glow_color;
        }
    }

    // Apply enhanced pulse to glow
    glow *= (glow_intensity * pulse) / ((glow_size * 2.0 + 1.0) * (glow_size * 2.0 + 1.0));

    // Make the glow color also pulse slightly
    vec4 pulsing_glow = glow;
    pulsing_glow.rgb *= pulse;

    // Combine original texture with enhanced pulsing glow
    COLOR = mix(pulsing_glow, texture_color, texture_color.a);
}