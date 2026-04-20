shader_type canvas_item;

// Parameters that we'll animate
uniform vec4 highlight_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);  // The color that expands
uniform vec4 base_color : source_color = vec4(vec4(1.0, 1.0, 1.0, 0.3098)
);  // Base color of the panel (change this to your desired color)
uniform float radius : hint_range(0.0, 1.5) = 0.0;  // Radius of the expanding circle
uniform float smoothness : hint_range(0.0, 0.5) = 0.05;  // Edge smoothness of the circle
uniform float opacity : hint_range(0.0, 1.0) = 1.0;  // Overall opacity for fade in/out

void fragment() {
    // Convert UV from 0.0-1.0 range to -1.0 to 1.0 for easier center calculations
    vec2 centered_uv = (UV - 0.5) * 2.0;

    // Calculate distance from center
    float dist = length(centered_uv);

    // Create a smooth circle mask
    float circle_mask = smoothstep(radius, radius - smoothness, dist);

    // Apply the highlight color with the mask and overall opacity
    vec4 final_color = mix(base_color, highlight_color, circle_mask * opacity);

    COLOR = final_color;
}