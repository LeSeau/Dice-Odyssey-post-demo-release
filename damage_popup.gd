extends Node2D
@onready var label: Label = $Label
var fade_duration: float = 0.6

const DICE_TYPE_COLORS := {
    "blue": Color(0.4, 0.7, 1.0),
    "red": Color(1.0, 0.25, 0.2),
    "evil": Color(0.85, 0.3, 0.85),
    "giant": Color(0.75, 1.0, 0.35),
    "magma": Color(1.0, 0.45, 0.05),
    "even": Color(1.0, 0.65, 0.3),
    "odd": Color(1.0, 0.85, 0.1),
    "green": Color(0.1, 1.0, 0.55),
    "mech": Color(0.8, 0.8, 0.85),
}

func show_damage(amount: int, dice_type: String = "") -> void:
    label.text = "-" + str(amount)

    if DICE_TYPE_COLORS.has(dice_type):
        label.add_theme_color_override("font_color", DICE_TYPE_COLORS[dice_type])

    # Resting size scales with damage, so a big hit's number stays visibly bigger the
    # whole time it's on screen (not just for the spawn punch). ~1 dmg -> 1.0, 24+ -> 1.6.
    var rest_scale: float = clampf(1.0 + amount / 40.0, 1.0, 1.6)

    # Tiny random rotation + small spawn offset so each number feels individually "thrown"
    # rather than stamped, and stacked/AoE hits don't land perfectly on top of each other.
    label.rotation = deg_to_rad(randf_range(-8.0, 8.0))
    position += Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 6.0))

    # Pop-in with overshoot: snap up from nothing, past the resting size, then settle -
    # so even small hits get a real pop (the old version started big and only shrank).
    label.scale = Vector2(0.3, 0.3)
    var scale_tween := create_tween()
    scale_tween.tween_property(label, "scale", Vector2(rest_scale * 1.18, rest_scale * 1.18), 0.09) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    scale_tween.tween_property(label, "scale", Vector2(rest_scale, rest_scale), 0.12) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    # Slay the Spire-style: punchy little hop with sideways kick, then a long
    # fall well past the bottom of its starting point, accelerating the whole
    # way down, fading out only near the very end of the fall
    var drift = randf_range(-35.0, 35.0)
    var fall_distance = 160.0
    var fall_duration = fade_duration - 0.1
    var pos_tween := create_tween()
    pos_tween.tween_property(self, "position", position + Vector2(drift, -32.0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pos_tween.tween_property(self, "position", position + Vector2(drift, fall_distance), fall_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

    var fade_tween := create_tween()
    fade_tween.tween_interval(fade_duration * 0.6)
    fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration * 0.4)
    fade_tween.tween_callback(queue_free)
