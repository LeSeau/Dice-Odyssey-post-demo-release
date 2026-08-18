extends CanvasLayer

# Centered act announcement over the map ("ACT 2: THE CATACOMBS"), STS-style.
# Same visual language as the in-battle TurnBanner (scenes/ui/turn_banner.gd) but
# method-triggered instead of signal-driven, since it fires exactly once per act
# transition (run.gd::_enter_act_2) rather than on a recurring game event. Lives
# on a high CanvasLayer so it draws above the map, the top bar and the legend.

@onready var control: Control = $Control
@onready var label: Label = $Control/Label
@onready var ribbon: TextureRect = $Control/Ribbon

# Layout position captured once, so the drift below always starts from the same place -
# reading label.position at announce() time would accumulate across acts.
var _base_label_y: float
var _base_ribbon_y: float


func _ready() -> void:
    control.modulate.a = 0.0
    label.pivot_offset = label.size / 2.0
    # Painted ribbon behind the text (2026-08-16) - shares the label's punch AND its
    # drift, so the announcement stays one object instead of text sliding over a plate.
    ribbon.pivot_offset = ribbon.size / 2.0
    _base_label_y = label.position.y
    _base_ribbon_y = ribbon.position.y


func announce(text: String) -> void:
    label.text = text
    control.modulate.a = 1.0
    label.scale = Vector2(0.6, 0.6)
    label.position.y = _base_label_y
    ribbon.scale = Vector2(0.6, 0.6)
    ribbon.position.y = _base_ribbon_y

    # Total beat is ~2.2s (0.18 punch + 0.12 settle + 1.25 hold + 0.65 fade). This has
    # been shortened twice on Julien's feedback: ~3.4s was "really too long", then 3.0
    # was still too long. Keep the pieces summing to the target if any are retuned.
    var tween := create_tween()
    tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.18) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # Still a longer hold than the turn banner - an act announcement is a bigger beat
    # and nothing is waiting on it (the map is already interactive underneath). A slow
    # drift up across the whole beat keeps it alive rather than frozen (runs in
    # parallel with the scale/hold/fade chain, so its duration is the total, not extra).
    tween.parallel().tween_property(label, "position:y", _base_label_y - 11.0, 2.2) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_interval(1.25)
    tween.tween_property(control, "modulate:a", 0.0, 0.65) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
