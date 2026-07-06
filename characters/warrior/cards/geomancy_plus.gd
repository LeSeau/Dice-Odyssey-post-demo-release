extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value <= 6:
        Events.reset_charged_card.emit()
        Global.roll_value*=3
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
