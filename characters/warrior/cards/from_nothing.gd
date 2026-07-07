extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    # Only a genuinely ROLLED 0 counts (the Evil die's 0-face): roll_value == 0
    # alone is ambiguous with the not-yet-rolled state - roll_history emptiness
    # disambiguates, same rule as Card.has_active_roll().
    if Global.roll_history.is_empty() or Global.roll_value != 0:
        return
    Global.roll_value += 12
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler) -> String:
    if has_active_roll() and Global.roll_value == 0:
        return "Your roll is 0: gain 12 Power"
    return "If your current roll is 0: gain 12 Power"
