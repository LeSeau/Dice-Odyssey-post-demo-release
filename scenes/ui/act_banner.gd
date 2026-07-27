extends CanvasLayer

# Centered act announcement over the map ("ACT 2: THE CATACOMBS"), STS-style.
# Same visual language as the in-battle TurnBanner (scenes/ui/turn_banner.gd) but
# method-triggered instead of signal-driven, since it fires exactly once per act
# transition (run.gd::_enter_act_2) rather than on a recurring game event. Lives
# on a high CanvasLayer so it draws above the map, the top bar and the legend.

@onready var control: Control = $Control
@onready var label: Label = $Control/Label

# Layout position captured once, so the drift below always starts from the same place -
# reading label.position at announce() time would accumulate across acts.
var _base_label_y: float


func _ready() -> void:
    control.modulate.a = 0.0
    label.pivot_offset = label.size / 2.0
    _base_label_y = label.position.y


func announce(text: String) -> void:
    label.text = text
    control.modulate.a = 1.0
    label.scale = Vector2(0.6, 0.6)
    label.position.y = _base_label_y

    var tween := create_tween()
    tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.22) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.16) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # Much longer hold than the turn banner - an act announcement is a bigger beat and
    # nothing is waiting on it (the map is already interactive underneath). Lengthened
    # on Julien's request: this is the first thing a new player ever reads, so it gets
    # time to land instead of blinking past. A slow drift up across the whole beat keeps
    # it alive rather than frozen (runs in parallel with the scale/hold/fade chain).
    tween.parallel().tween_property(label, "position:y", _base_label_y - 16.0, 3.4) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_interval(2.3)
    tween.tween_property(control, "modulate:a", 0.0, 0.75) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
