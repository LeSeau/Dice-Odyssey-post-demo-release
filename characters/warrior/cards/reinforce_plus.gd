extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    print("Reinforce applied")
    if Global.roll_value <= 12:
        Events.reset_charged_card.emit()
        Global.roll_value+=2
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.draw_card.emit(1)
    Events.reset_charged_card.emit()
