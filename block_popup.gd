extends Node2D
@onready var label: Label = $Label
var fade_duration: float = 0.6

# tint defaults to the authored icy blue so any existing caller is unaffected; the
# player's own block is tinted by the active dice type (see BlockEffect).
func show_block(amount: int, tint := Color(0.4, 0.75, 1.0)) -> void:
    label.text = "+" + str(amount)
    # LabelSettings is a SHARED sub-resource - duplicate before touching font_color or
    # every block popup in the scene changes colour with it.
    if label.label_settings:
        label.label_settings = label.label_settings.duplicate()
        label.label_settings.font_color = tint

    var punch_scale = 1.0 + (amount / 50.0)
    punch_scale = clamp(punch_scale, 1.0, 1.6)
    label.scale = Vector2(punch_scale, punch_scale)

    var tween := create_tween()
    tween.set_parallel(true)

    tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    var drift = randf_range(-15.0, 15.0)
    tween.tween_property(self, "position", position + Vector2(drift, -50), fade_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

    # Ease-IN fade, matching damage_popup (2026-08-15, STS2 audit 4.4): holds readable
    # almost the whole way, then drops off at the end.
    var fade_tween := create_tween()
    fade_tween.tween_interval(fade_duration * 0.45)
    fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration * 0.55) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

    tween.chain().tween_callback(queue_free)
