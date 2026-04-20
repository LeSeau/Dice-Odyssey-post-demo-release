extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void: 
    var dice_amount_to_return = Global.roll_history.size()
    
    var property_name := "%s_dice_current_amount" % "red"
    Global.set(property_name, Global.get(property_name) + dice_amount_to_return)
    
    Events.change_current_power.emit()
    
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)

    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
