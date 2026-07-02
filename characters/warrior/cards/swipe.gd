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

        Events.change_current_power.emit()
        
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_amount_changed.emit()

        var oracle_card3 = load("res://characters/warrior/cards/card_scout3.tres")
        Events.add_card_to_hand_requested.emit(oracle_card3)
        Events.reset_charged_card.emit()  
        
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal ? damage. Get a Scout 3 Card"
    if not has_active_roll():
        return "Deal X damage. Get a Scout 3 Card"
    var total := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    return "Deal %d damage. Get a Scout 3 Card" % total
