extends Node

# ============================================================================
# IMPACT LADDER (2026-08-15, STS2 audit 4.2/4.3)
#
# One shared vocabulary for "how big was that?", used by hit_stop and by shake.
# Before this, every call site invented its own float via an ad-hoc clampf, so the
# relationship between a 6-damage poke and a 20-damage haymaker was encoded in a
# magic multiplier at each of ~9 sites.
#
# NOTE the deliberate jump between WEAK and MEDIUM: there is no gentle slope between
# "a tap" and "a real hit". A ladder that ramps smoothly stops reading as a ladder.
# ============================================================================

enum Impact { VERY_WEAK, WEAK, MEDIUM, STRONG, HUGE }

# Shake amplitude in px, per rung.
const SHAKE_MAGNITUDE := {
    Impact.VERY_WEAK: 2.0,
    Impact.WEAK: 5.0,
    Impact.MEDIUM: 14.0,
    Impact.STRONG: 22.0,
    Impact.HUGE: 32.0,
}

# Shake outlasts the freeze at every rung on purpose: you come OUT of the slow-motion
# while the screen is still moving, which is what sells recoil rather than a hitch.
const SHAKE_DURATION := {
    Impact.VERY_WEAK: 0.12,
    Impact.WEAK: 0.18,
    Impact.MEDIUM: 0.30,
    Impact.STRONG: 0.42,
    Impact.HUGE: 0.55,
}

# Hit-stop duration in seconds, per rung.
const HIT_STOP_DURATION := {
    Impact.VERY_WEAK: 0.06,
    Impact.WEAK: 0.10,
    Impact.MEDIUM: 0.16,
    Impact.STRONG: 0.24,
    Impact.HUGE: 0.34,
}

# Which curve the freeze RECOVERS along, per rung. This is where the expressiveness
# lives - not in the depth. All are EASE_IN on a 0.1 -> 1.0 ramp, so the value lingers
# near the bottom and then rushes back; the curve decides how long it lingers.
# Ordered by "time spent still frozen" (measured at the ramp's midpoint):
#   SINE 0.29 -> QUAD 0.25 -> CUBIC 0.13 -> QUART 0.06 -> EXPO 0.03
# so a VERY_WEAK tap flicks out of the freeze while a HUGE hit sits in it and slams back.
const HIT_STOP_TRANS := {
    Impact.VERY_WEAK: Tween.TRANS_SINE,
    Impact.WEAK: Tween.TRANS_QUAD,
    Impact.MEDIUM: Tween.TRANS_CUBIC,
    Impact.STRONG: Tween.TRANS_QUART,
    Impact.HUGE: Tween.TRANS_EXPO,
}

# Freeze depth. Raised 0.02 -> 0.1 (2026-08-15, STS2 audit 4.2). The history matters:
# the old comment recorded that depth was pushed all the way down to 0.02 because the
# effect was "imperceptible" at 0.05 - but that was compensating for the SHAPE, not the
# depth. A flat hold followed by an instant snap back to full speed is exactly what reads
# as a hitch rather than an impact; the snap is the ugly part. Now that recovery RAMPS
# along a curve, a shallower (and much safer) freeze feels heavier than the old deep one,
# and nothing in the game ever hard-cuts back to normal speed.
const HIT_STOP_DEPTH := 0.1


# Map a raw damage number onto the ladder, so damage-driven call sites stop hand-rolling
# clampf curves. Thresholds are tuned against act-1 reality: routine hits are 3-8, a big
# early hit is ~12, DamageEffect's BIG_HIT_THRESHOLD (camera punch zoom) is 15.
static func impact_for_damage(damage: int) -> Impact:
    if damage <= 2:
        return Impact.VERY_WEAK
    elif damage <= 7:
        return Impact.WEAK
    elif damage <= 14:
        return Impact.MEDIUM
    elif damage <= 24:
        return Impact.STRONG
    return Impact.HUGE


# Map a normalized 0..1 intensity onto the ladder, for call sites whose "size" isn't
# damage (roll value as a fraction of the die's max face, charge counts, Power deltas).
static func impact_for_fraction(t: float) -> Impact:
    var f := clampf(t, 0.0, 1.0)
    if f < 0.15:
        return Impact.VERY_WEAK
    elif f < 0.4:
        return Impact.WEAK
    elif f < 0.7:
        return Impact.MEDIUM
    elif f < 0.95:
        return Impact.STRONG
    return Impact.HUGE


# ---------------------------------------------------------------------------
# Node shake
# ---------------------------------------------------------------------------

# Horizontal-only node shake with a rise-and-fall envelope (2026-08-15, STS2 audit 4.3).
# Replaces the old 2D `shake()` helper, which had ZERO callers and two comments in the
# codebase actively warning people off it.
#
# Two reasons X-only rather than 2D:
#   1. A creature standing on the ground that jitters VERTICALLY reads as levitating -
#      and we spent multiple sessions getting every enemy planted on a consistent ground
#      line (the feet_line_y work). A 2D jitter partially undoes that on every hit.
#   2. The envelope (a fast oscillation multiplied by a slow half-sine that grows then
#      dies) is the difference between a recoil and a rattle. Constant-amplitude-then-stop
#      reads as a glitch; grow-then-decay reads as an impact.
# Apply to a child visuals node, never a root that something else positions.
func shake_horizontal(thing: Node2D, amplitude: float, duration: float = 0.5,
        cycles: float = 4.0) -> void:
    if not is_instance_valid(thing):
        return
    var rest_x := thing.position.x
    var step := func(t: float) -> void:
        if not is_instance_valid(thing):
            return
        # sin(t*TAU*cycles) is the oscillation; sin(t*PI) is the envelope - 0 at both
        # ends, 1 in the middle - so it grows in and dies out instead of clipping off.
        var envelope: float = sin(t * PI)
        thing.position.x = rest_x + sin(t * TAU * cycles) * amplitude * envelope
    var tween := create_tween()
    tween.tween_method(step, 0.0, 1.0, duration) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_callback(func() -> void:
        if is_instance_valid(thing):
            thing.position.x = rest_x
    )


func shake_horizontal_impact(thing: Node2D, impact: Impact) -> void:
    shake_horizontal(thing, SHAKE_MAGNITUDE[impact], SHAKE_DURATION[impact])


# ---------------------------------------------------------------------------
# Hit stop
# ---------------------------------------------------------------------------

# The recovery ramp is driven by hand in _process against REAL time, not by a Tween.
# Three reasons, all learned the hard way (see debug_feel_pass.gd):
#   * a Tween animating Engine.time_scale is itself slowed by the value it is animating,
#     so the ramp would decelerate itself;
#   * Tween.set_ignore_time_scale() does NOT exist in Godot 4.3 - calling it throws, and
#     because the throw happened inside a coroutine it also skipped the restore, leaving
#     the entire game running at 0.1 speed permanently;
#   * tween_property(Engine, "time_scale", ...) does not work either - Engine is a
#     singleton Object outside the scene tree.
# Doing the interpolation manually sidesteps all three, and Tween.interpolate_value is
# still available as a STATIC helper, so the easing curves cost nothing.
#
# CLOCK (2026-09-05, trailer capture). The wall clock below is right for the shipped game and
# WRONG for every capture, because a forced timestep decouples wall time from output time:
#   * --fixed-fps headless: a frame costs ~1 ms of wall time, so wall time crawls against
#     frames and a 0.34 s freeze stretches past 4000 frames (measured, it never recovered);
#   * --write-movie: a frame costs 50-100 ms to encode, so wall time races and the same
#     freeze collapses to two frames, turning every impact in the video into a stutter.
# Rather than re-derive output time from `delta` (which is scaled by the very value being
# ramped, and lags a frame behind it, so the arithmetic is fragile exactly when frame times
# jitter), a capture harness declares the timestep it is running at and the ramp counts
# frames. `capture_frame_step` is 0.0 in every shipped build, so the wall-clock path here is
# byte-for-byte the one that has always shipped and no playtested feel changes.
# Pinned by debug_trailer_hitstop.gd, which asserts frames under a forced timestep and real
# seconds under a variable one.
var capture_frame_step := 0.0

var _ramp_active := false
var _ramp_elapsed := 0.0
var _ramp_start_ms := 0
var _ramp_duration := 0.0
var _ramp_from := 1.0
var _ramp_trans: Tween.TransitionType = Tween.TRANS_QUAD


func _ready() -> void:
    # A hit-stop can be in flight when something pauses the tree (map consult, the battle
    # over panel). Without ALWAYS the ramp would freeze mid-way and the game would come
    # back from the pause still in slow motion.
    process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
    if not _ramp_active:
        return
    if capture_frame_step > 0.0:
        # One rendered frame is one step of output time, whatever it cost to produce.
        _ramp_elapsed += capture_frame_step
    else:
        # Real elapsed time - deliberately not `delta`, which is scaled by the very value
        # being animated.
        _ramp_elapsed = float(Time.get_ticks_msec() - _ramp_start_ms) / 1000.0
    if _ramp_elapsed >= _ramp_duration or _ramp_duration <= 0.0:
        Engine.time_scale = 1.0
        _ramp_active = false
        return
    Engine.time_scale = Tween.interpolate_value(
        _ramp_from, 1.0 - _ramp_from,
        _ramp_elapsed, _ramp_duration,
        _ramp_trans, Tween.EASE_IN)


# `duration` and `time_scale` keep their old meaning so existing call sites are untouched;
# `trans` selects the recovery curve (see HIT_STOP_TRANS above).
func hit_stop(duration: float = 0.05, time_scale: float = HIT_STOP_DEPTH,
        trans: Tween.TransitionType = Tween.TRANS_QUAD) -> void:
    # Deepen instantly - the freeze has to be felt on the exact frame of impact. minf so a
    # shallower overlapping call can never lighten a deeper freeze already in progress.
    Engine.time_scale = minf(Engine.time_scale, time_scale)

    # "Longest wins" when calls overlap - e.g. an AoE card fires one hit_stop per target,
    # and a damage hit plus an EXACT-requirement bonus can land in the same moment. A new
    # call only takes over the recovery curve if it would finish LATER than the one already
    # running; otherwise a short poke landing right after a haymaker would replace the
    # haymaker's long ramp with its own short one and end the freeze early. This replaces
    # the old reference counting, which solved the same problem for a flat hold.
    #
    # (The reference CANCELS its previous hit-stop instead of composing. Ours is
    # deliberately the other way round, for the AoE reason above.)
    # Compared as time REMAINING on the running ramp, which is the same test the old
    # wall-clock end-stamp made, expressed on whichever clock the ramp is running on.
    var remaining := 0.0
    if _ramp_active:
        remaining = _ramp_duration - _ramp_elapsed
    if not _ramp_active or duration > remaining:
        _ramp_active = true
        _ramp_elapsed = 0.0
        _ramp_start_ms = Time.get_ticks_msec()
        _ramp_duration = duration
        _ramp_from = Engine.time_scale
        _ramp_trans = trans


# Ladder-driven wrapper: one call expresses depth, duration AND curve together.
func hit_stop_impact(impact: Impact) -> void:
    hit_stop(HIT_STOP_DURATION[impact], HIT_STOP_DEPTH, HIT_STOP_TRANS[impact])
