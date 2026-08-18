extends Control

@onready var label: Label = $Label
@onready var ribbon: TextureRect = $Ribbon

func _ready() -> void:
    modulate.a = 0.0
    label.pivot_offset = label.size / 2.0
    # The painted ribbon behind the text (2026-08-16). It must share the label's punch, or
    # the text springs in while the plate sits still - two objects instead of one banner.
    ribbon.pivot_offset = ribbon.size / 2.0
    Events.player_turn_started.connect(_on_player_turn_started)

func _on_player_turn_started() -> void:
    # Skip the very first turn of a fight - it reads as off/redundant right as combat
    # starts. Global.fight_turn is still 0 at that point (player_handler.gd only
    # increments it in end_turn(), so it's 0 for turn 1 and 1+ for every turn after).
    if Global.fight_turn == 0:
        return

    modulate.a = 1.0
    label.scale = Vector2(0.6, 0.6)
    ribbon.scale = Vector2(0.6, 0.6)

    var tween := create_tween()
    tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(ribbon, "scale", Vector2(1.1, 1.1), 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(ribbon, "scale", Vector2(1.0, 1.0), 0.1) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_interval(0.55)
    tween.tween_property(self, "modulate:a", 0.0, 0.35) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
