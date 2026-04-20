extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
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
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")
