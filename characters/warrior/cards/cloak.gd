extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    if Global.roll_value % 2 == 1:
        var active_dice = Global.dice_type
        var dice_amount_variable = active_dice + "_dice_current_amount"
        
        # Check if the variable exists in Global
        if dice_amount_variable in Global:
            # Update the corresponding amount dynamically
            var current_amount = Global.get(dice_amount_variable)
            Global.set(dice_amount_variable, current_amount + 1)
            
            Events.change_current_power.emit()
            
            var support_effect := SupportEffect.new()
            support_effect.sound = sound
            support_effect.execute(targets)
            Events.dice_charged.emit(active_dice, 1)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
    Events.dice_amount_changed.emit()
