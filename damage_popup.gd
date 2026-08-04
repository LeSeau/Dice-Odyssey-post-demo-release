extends Node2D
@onready var label: Label = $Label
var fade_duration: float = 0.6

# All the "how punchy is this hit" scaling below rides on one shared 0..1 curve rather
# than each having its own independent cap - keeps a 3 dmg poke and a 20 dmg haymaker
# feeling like coherently different POINTS on the same scale instead of a grab bag of
# unrelated thresholds. Reaches full punch at PUNCH_DAMAGE_CAP; DamageEffect's own
# BIG_HIT_THRESHOLD (15, for camera zoom) sits just below that so the popup is already
# near max punch by the time the camera joins in.
const PUNCH_DAMAGE_CAP := 22.0

# Start scale for the pop-in tween - small hits start CLOSE to their resting size (a
# gentle, quiet grow-in) so they don't add noise; big hits start tiny and rocket up,
# which reads as a much sharper snap purely from having more distance to cover.
const START_SCALE_MIN := 0.55
const START_SCALE_MAX := 0.15

# How much bigger than its resting size the number overshoots on the way in - a small
# poke barely overshoots, a big hit snaps up noticeably past its final size before
# settling, so the PUNCH itself (not just the resting size) reads as bigger.
const OVERSHOOT_MIN := 1.04
const OVERSHOOT_MAX := 1.6

# Bright warm-white the number flashes to for an instant at spawn before settling back
# to its true (red) color - barely a flicker on a weak hit, a proper hot flash on a big
# one. Same overbright-then-normal-modulate trick used for the reward panel's landing
# flash.
const SPAWN_FLASH_MIN := Color(1.12, 1.1, 1.05, 1.0)
const SPAWN_FLASH_MAX := Color(2.1, 1.9, 1.55, 1.0)
const SPAWN_FLASH_SETTLE_DURATION := 0.1

# Height of the little upward hop at spawn (see the position tween below) - a light tap
# barely lifts off, a big hit gets a proper kick upward.
const HOP_HEIGHT_MIN := 14.0
const HOP_HEIGHT_MAX := 42.0

# "Blocked" popup styling (fully-absorbed hits): steel blue instead of damage red, a
# notch smaller than the numbers - it's information, not pain. Punch kept gentle.
const BLOCKED_COLOR := Color(0.55, 0.75, 0.95)
const BLOCKED_DARK_COLOR := Color(0.03, 0.09, 0.18)
const BLOCKED_FONT_SIZE := 28
const BLOCKED_PUNCH_T := 0.18


func show_damage(amount: int) -> void:
    label.text = "-" + str(amount)
    var punch_t := clampf(amount / PUNCH_DAMAGE_CAP, 0.0, 1.0)

    # Resting size scales with damage, so a big hit's number stays visibly bigger the
    # whole time it's on screen (not just for the spawn punch). ~1 dmg -> 1.0, 24+ -> 1.6.
    var rest_scale: float = clampf(1.0 + amount / 40.0, 1.0, 1.6)
    _animate(punch_t, rest_scale)


func show_blocked() -> void:
    label.text = "Blocked"
    # LabelSettings is a sub-resource shared by every popup instance - duplicate before
    # recoloring or every damage number in the fight turns blue with it.
    label.label_settings = label.label_settings.duplicate()
    label.label_settings.font_color = BLOCKED_COLOR
    label.label_settings.outline_color = BLOCKED_DARK_COLOR
    label.label_settings.shadow_color = BLOCKED_DARK_COLOR
    label.label_settings.font_size = BLOCKED_FONT_SIZE
    _animate(BLOCKED_PUNCH_T, 1.0)


func _animate(punch_t: float, rest_scale: float) -> void:
    var overshoot_mult := lerpf(OVERSHOOT_MIN, OVERSHOOT_MAX, punch_t)
    var start_scale := lerpf(START_SCALE_MIN, START_SCALE_MAX, punch_t)
    var hop_height := lerpf(HOP_HEIGHT_MIN, HOP_HEIGHT_MAX, punch_t)

    # Tiny random rotation + small spawn offset so each number feels individually "thrown"
    # rather than stamped, and stacked/AoE hits don't land perfectly on top of each other.
    label.rotation = deg_to_rad(randf_range(-8.0, 8.0))
    position += Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 6.0))

    # Spawn flash: instant bright modulate that settles back to normal (true red) over a
    # short window, layered on top of the scale punch below for extra "sharp".
    label.modulate = SPAWN_FLASH_MIN.lerp(SPAWN_FLASH_MAX, punch_t)
    var flash_tween := create_tween()
    flash_tween.tween_property(label, "modulate", Color.WHITE, SPAWN_FLASH_SETTLE_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    # Pop-in with overshoot: snap up from nothing, past the resting size, then settle -
    # so even small hits get a real pop (the old version started big and only shrank).
    # Fast punch + a tight (non-wobbly) settle for a sharp "snap" rather than a smooth/
    # floaty grow-in - the actual DISTANCE traveled (start_scale/overshoot_mult above) is
    # what varies with hit size, not the tempo.
    label.scale = Vector2(start_scale, start_scale)
    var scale_tween := create_tween()
    scale_tween.tween_property(label, "scale", Vector2(rest_scale * overshoot_mult, rest_scale * overshoot_mult), 0.055) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    scale_tween.tween_property(label, "scale", Vector2(rest_scale, rest_scale), 0.08) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

    # Slay the Spire-style: punchy little hop with sideways kick, then a long
    # fall well past the bottom of its starting point, accelerating the whole
    # way down, fading out only near the very end of the fall
    var drift = randf_range(-35.0, 35.0)
    var fall_distance = 160.0
    var fall_duration = fade_duration - 0.1
    var pos_tween := create_tween()
    pos_tween.tween_property(self, "position", position + Vector2(drift, -hop_height), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pos_tween.tween_property(self, "position", position + Vector2(drift, fall_distance), fall_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

    var fade_tween := create_tween()
    fade_tween.tween_interval(fade_duration * 0.6)
    fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration * 0.4)
    fade_tween.tween_callback(queue_free)
