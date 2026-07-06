extends CanvasLayer

# Centered act announcement over the map ("ACT 2: THE CATACOMBS"), STS-style.
# Same visual language as the in-battle TurnBanner (scenes/ui/turn_banner.gd) but
# method-triggered instead of signal-driven, since it fires exactly once per act
# transition (run.gd::_enter_act_2) rather than on a recurring game event. Lives
# on a high CanvasLayer so it draws above the map, the top bar and the legend.

@onready var control: Control = $Control
@onready var label: Label = $Control/Label


func _ready() -> void:
    control.modulate.a = 0.0
    label.pivot_offset = label.size / 2.0


func announce(text: String) -> void:
    label.text = text
    control.modulate.a = 1.0
    label.scale = Vector2(0.6, 0.6)

    var tween := create_tween()
    tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.15) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # Longer hold than the turn banner - an act announcement is a bigger beat and
    # nothing is waiting on it (the map is already interactive underneath).
    tween.tween_interval(1.4)
    tween.tween_property(control, "modulate:a", 0.0, 0.5) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
