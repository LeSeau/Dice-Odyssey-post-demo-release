extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    print("Reinforce applied")
    if meets_requirement():
        Events.reset_charged_card.emit()
        Global.roll_value*=3
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
