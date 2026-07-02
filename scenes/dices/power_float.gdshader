shader_type canvas_item;

// Movement for the Power number. Driven in the vertex shader (GPU-side, continuous TIME)
// on purpose - Control nodes in this project snap .position to whole pixels at render time
// (gui/common/snap_controls_to_pixels), so any script-side Tween or per-frame position
// animation on a Label shows up as visible 1px jumps. A vertex offset here stays smooth.
// All motion is gated by float_intensity (0 when power == 0) so the number sits dead still
// with no power banked.

// Slow ambient drift - the underlying "alive" float.
uniform float amplitude_x : hint_range(0.0, 20.0) = 4.0;
uniform float amplitude_y : hint_range(0.0, 20.0) = 5.0;
uniform float speed_x : hint_range(0.0, 5.0) = 0.55;
uniform float speed_y : hint_range(0.0, 5.0) = 0.81;
uniform float float_intensity : hint_range(0.0, 1.0) = 1.0;

// Gentle breathing scale (only ever swells up, never shrinks below resting).
uniform float breathe_amplitude : hint_range(0.0, 0.4) = 0.05;
uniform float breathe_speed : hint_range(0.0, 5.0) = 0.4;
uniform vec2 local_pivot = vec2(45.0, 48.0);

// "Crepitement": a fast, nervous, slightly-irregular tremor layered on top of the slow
// drift, so the number reads as crackling with contained energy / eager to be unleashed,
// rather than calmly floating. Smoothed pseudo-random jitter (not pure sine) for that
// crackle feel; smoothstep between samples keeps it nervous without hard strobing.
uniform float crackle_amplitude : hint_range(0.0, 8.0) = 1.5;
uniform float crackle_freq : hint_range(0.0, 40.0) = 11.0;
// Driven from GDScript separately from float_intensity: scales the crackle specifically
// (not the ambient breathe/drift) with banked power this turn - barely perceptible at low
// power, reaching the crackle_amplitude above (the existing always-on look) at ~12+ power,
// so a low roll feels calm and a big turn feels like it's about to go off.
uniform float crackle_charge : hint_range(0.0, 2.0) = 0.0;

float hash11(float p) {
    return fract(sin(p * 127.1) * 43758.5453);
}

float crackle(float seed) {
    float tf = TIME * crackle_freq;
    float i0 = floor(tf);
    float fr = fract(tf);
    fr = fr * fr * (3.0 - 2.0 * fr); // smoothstep easing between random samples
    return mix(hash11(i0 + seed) - 0.5, hash11(i0 + seed + 1.0) - 0.5, fr);
}

void vertex() {
    float t = TIME;

    float breathe = 1.0 + (sin(t * breathe_speed) * 0.5 + 0.5) * breathe_amplitude * float_intensity;
    VERTEX = local_pivot + (VERTEX - local_pivot) * breathe;

    // Slow drift.
    VERTEX.x += sin(t * speed_x) * amplitude_x * float_intensity;
    VERTEX.y += sin(t * speed_y + 1.4) * amplitude_y * float_intensity;

    // Fast crackle tremor (decorrelated seeds per axis) - scaled by crackle_charge, not
    // float_intensity, so it ramps with banked power rather than snapping fully on/off.
    VERTEX.x += crackle(0.0) * crackle_amplitude * crackle_charge;
    VERTEX.y += crackle(31.0) * crackle_amplitude * crackle_charge;
}
