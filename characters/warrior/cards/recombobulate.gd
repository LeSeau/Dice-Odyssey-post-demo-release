extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void: 
    var dice_amount_to_return = Global.roll_history.size()
    
    var property_name := "%s_dice_current_amount" % Global.dice_type
    Global.set(property_name, Global.get(property_name) + dice_amount_to_return)
    

    
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.refuel_happened.emit(Global.roll_value)
    Events.dice_roll_reset.emit()
    Events.change_current_power.emit()
    Events.dice_amount_changed.emit()
    Events.reset_charged_card.emit()

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this refunds one die per roll in the current chain,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
func plays_at_zero_power() -> bool:
    return true
