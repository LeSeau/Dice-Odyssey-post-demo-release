shader_type canvas_item;

// Colors
uniform vec4 magic_color : source_color = vec4(0.35, 0.6, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.1, 0.35, 1.0, 1.0);

// Tunables
uniform float glow_strength : hint_range(0.0, 3.0) = 0.0;
uniform float border_size : hint_range(0.02, 0.35) = 0.12;
uniform float border_softness : hint_range(0.01, 0.25) = 0.06;
uniform float wave_speed : hint_range(0.1, 3.0) = 0.9;
uniform float noise_scale : hint_range(1.0, 8.0) = 3.5;
uniform float square_roundness : hint_range(0.0, 1.0) = 0.35;
uniform sampler2D socket_mask : hint_default_white;
uniform bool use_mask_alpha = false;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f*f*(3.0 - 2.0*f);
    float a = hash(i);
    float b = hash(i + vec2(1.0,0.0));
    float c = hash(i + vec2(0.0,1.0));
    float d = hash(i + vec2(1.0,1.0));
    return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

// BORDER SHAPE
float square_border(vec2 uv, float size, float softness, float roundness) {
    vec2 centered = abs(uv - 0.5);
    float square_dist = max(centered.x, centered.y);
    float circle_dist = length(centered);
    float dist = mix(square_dist, circle_dist, roundness);
    float outer_edge = 0.5 - size;
    float inner_edge = outer_edge + softness;
    return 1.0 - smoothstep(outer_edge, inner_edge, dist);
}

void fragment() {
    vec2 uv = UV;

    // mask?
    float mask_alpha = use_mask_alpha ? texture(socket_mask, uv).a : 1.0;

    // BORDER mask ONLY
    float border_mask = square_border(uv, border_size, border_softness, square_roundness);

    // animated noise
    float t = TIME * wave_speed;
    float n1 = noise((uv - 0.5) * noise_scale + vec2(t * 0.2, -t * 0.15));
    float n2 = noise((uv - 0.5) * noise_scale * 1.8 - vec2(t * 0.35, t * 0.1));
    float combined = mix(n1, n2, 0.5);

    // light movement
    float sq = sin((abs(uv.x - 0.5) + abs(uv.y - 0.5)) * 15.0 + t * 1.2) * 0.12;
    float dynamic = clamp(combined * 0.6 + sq * 0.4, -1.0, 1.0);

    float effect = border_mask * (0.6 + 0.8 * dynamic) * glow_strength;

    // COLOR + *border only*
    vec3 col = mix(magic_color.rgb, accent_color.rgb, combined * 0.5 + 0.5);
    float alpha = effect * mask_alpha;

    // FINAL COLOR (center = fully transparent)
    COLOR = vec4(col, alpha);
}
