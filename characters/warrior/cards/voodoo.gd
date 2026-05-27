extends Card
func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void: 
    var dice_amount_to_return = Global.roll_history.size()
    
    var all_dice_types = ["blue", "red", "even", "odd", "giant", "green", "evil", "magma", "mech"]
    var random_dice = all_dice_types[randi() % all_dice_types.size()]
    
    var property_name := "%s_dice_current_amount" % random_dice
    Global.set(property_name, Global.get(property_name) + dice_amount_to_return)
    
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.refuel_happened.emit(Global.roll_value)
    Events.temporary_dice_added.emit(random_dice)
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
    Events.reset_charged_card.emit()
