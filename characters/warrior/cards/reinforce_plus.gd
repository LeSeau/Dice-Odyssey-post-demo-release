extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    Global.roll_value+=4
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this adds a flat 4 Power,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
func plays_at_zero_power() -> bool:
    return true
