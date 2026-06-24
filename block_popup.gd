extends Node2D
@onready var label: Label = $Label
var fade_duration: float = 0.6

func show_block(amount: int) -> void:
    label.text = "+" + str(amount)

    var punch_scale = 1.0 + (amount / 50.0)
    punch_scale = clamp(punch_scale, 1.0, 1.6)
    label.scale = Vector2(punch_scale, punch_scale)

    var tween := create_tween()
    tween.set_parallel(true)

    tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    var drift = randf_range(-15.0, 15.0)
    tween.tween_property(self, "position", position + Vector2(drift, -50), fade_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

    var fade_tween := create_tween()
    fade_tween.tween_interval(fade_duration * 0.5)
    fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration * 0.5)

    tween.chain().tween_callback(queue_free)
