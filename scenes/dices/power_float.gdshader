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

// OVERCHARGE (2026-08-26): past ~18 banked power the number stops merely trembling and
// starts BURNING. Driven by dice.gd::_update_overcharge() - one uniform, tweened, so this
// never touches the Label's modulate. That matters: the power number's modulate is a
// documented minefield of flash-and-restore-to-snapshot bugs (an orb landing mid-flash used
// to capture the lightened value as "resting" and ratchet the number to white), and a
// persistent tint fighting those tweens would reopen exactly that class of bug. A shader
// uniform sits underneath all of them and cannot be captured by any of them.
uniform float heat : hint_range(0.0, 1.0) = 0.0;
// PER-TYPE, driven from DicePalette by dice.gd::_update_power_ember_colors(). An earlier
// pass made these a fixed warm gold on the theory that fire has to be orange - Julien's
// verdict after playtesting was that the number must keep saying which die is active, and
// he is right: the Power number is the one element whose colour the whole HUD uses to
// answer "what am I rolling". So the number goes INCANDESCENT rather than orange - it
// swings between a richer version of its own accent and a near-white version of it, which
// reads as heat without ever leaving the die's hue. The warm gold now lives only on the
// embers coming off it, where it has to be warm to stay visible against the die's own light.
uniform vec4 ember_color : source_color = vec4(0.24, 0.48, 1.0, 1.0);
uniform vec4 ember_core : source_color = vec4(0.85, 0.90, 1.0, 1.0);
uniform float flicker_freq : hint_range(0.0, 40.0) = 17.0;
// How much the crackle tremor is multiplied at full heat, on top of crackle_charge.
uniform float heat_crackle_gain : hint_range(0.0, 4.0) = 1.6;

float hash11(float p) {
    return fract(sin(p * 127.1) * 43758.5453);
}

// 0..1 smoothed noise, same family as crackle() but used for BRIGHTNESS rather than
// position - a flame's light is unsteady even when the object holding it is still.
float flicker01() {
    float tf = TIME * flicker_freq;
    float i0 = floor(tf);
    float fr = fract(tf);
    fr = fr * fr * (3.0 - 2.0 * fr);
    return mix(hash11(i0 + 71.3), hash11(i0 + 72.3), fr);
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
    // Overcharge multiplies it further: crackle_charge has already saturated by ~12 power,
    // so without this the tremor would be identical at 12 and at 45 - the whole point of the
    // tier ladder is that the top of it does not look like the middle.
    float tremor = crackle_charge * (1.0 + heat * heat_crackle_gain);
    VERTEX.x += crackle(0.0) * crackle_amplitude * tremor;
    VERTEX.y += crackle(31.0) * crackle_amplitude * tremor;
}


void fragment() {
    // COLOR arrives as the interpolated vertex colour - for a Label that is font_color for
    // the glyph body and outline_color for the outline pass, each modulated by the node's
    // modulate. Reproducing the default (COLOR *= texture) is required once fragment() is
    // written at all; at heat == 0 this function is exactly that and nothing else.
    vec4 src = COLOR;
    if (heat > 0.001) {
        // Ignite the BODY only. The outline is what keeps the number legible on top of the
        // die's own light pool, so it has to stay dark - and it is separable for free here,
        // because the two passes arrive with different vertex colours.
        //
        // MAX CHANNEL, not luminance. Every dice accent has a channel at or near 1.0 while
        // being wildly different in luminance (mech 0.75, blue 0.47), so a luminance gate
        // ignited each type by a different amount - blue only reached 68%, and the 32% of
        // surviving blue cancelled the orange almost exactly, measuring "warm" while
        // rendering white. The outline is this same accent multiplied by a dark brown
        // (0.31, 0.08, 0.0), so its max channel stays under 0.22 even while the number is
        // flashed to lightened(0.6) on a roll - a clean gap either side of this ramp.
        float maxc = max(src.r, max(src.g, src.b));
        float body = smoothstep(0.30, 0.60, maxc);
        float fl = flicker01();

        // Two separate weights. BRIGHTNESS follows heat directly, so tier 1 already trembles
        // and glows harder; COLOUR comes in late and fast, so tier 1 stays recognisably the
        // die's own blue and only the upper tiers actually ignite. A single weight put the
        // number at a 30% tint the instant it crossed 18, which both spent the top of the
        // ladder early and looked muddy on the way.
        float glow_w = body * heat;
        float tint_w = body * smoothstep(0.25, 0.85, heat);

        // The near-white core is reached by FLICKER PEAKS, not by the heat level itself.
        // Blending it in on heat alone rendered a plain white number at the top tier -
        // measurably "warmer than blue" and visibly not on fire. Keyed to the flicker, the
        // glyph gutters between deep orange and hot cream instead.
        // pow() biases the flicker LOW: the number sits at its rich resting hue most of the
        // time and spikes white-hot only briefly, which is what reads as guttering rather
        // than as a permanently pale number.
        float core = clamp(pow(fl, 1.8) * (0.40 + 0.60 * heat), 0.0, 1.0);
        vec3 hot = mix(ember_color.rgb, ember_core.rgb, core);

        // No hue-drain step here any more. It existed because the old fixed-orange ember had
        // to cross the accent's hue to reach it, and blue->orange passes through MAGENTA
        // (tier 2 rendered salmon pink). Now that both ends of the swing are derived from
        // the accent itself there is no hue to cross, and draining to neutral would only
        // wash the colour the number is supposed to be keeping.
        src.rgb = mix(src.rgb, hot, tint_w);

        // Unsteady overbright on top of the tint: the number's own light guttering. Kept
        // well under the clipping point at rest so the colour survives instead of blowing
        // out to white on every frame.
        // Modest on purpose. The peak colour already sits at full value, so a large
        // multiplier clips the top channel while the others catch up - which desaturates
        // toward white and undoes the hue preservation above.
        src.rgb *= 1.0 + glow_w * (0.10 + 0.35 * fl);
    }
    COLOR = src * texture(TEXTURE, UV);
}
