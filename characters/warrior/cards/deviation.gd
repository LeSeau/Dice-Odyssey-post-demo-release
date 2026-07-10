extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if Global.roll_value % 2 == 0:
            
        var block_effect := BlockEffect.new()
        block_effect.amount = Global.roll_value
        block_effect.sound = sound
        block_effect.execute(targets)
        
        var all_dice = ["blue", "red", "green", "giant", "magma", "even", "odd", "mech"]
        var chosen = all_dice[randi() % all_dice.size()]
        Global.set(chosen + "_dice_current_amount", Global.get(chosen + "_dice_current_amount") + 1)
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit(chosen)
        
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Charge a random Dice"
    if not has_active_roll() or not meets_requirement():
        return "Block X. Charge a random Dice"
    return "Block %d. Charge a random Dice" % Global.roll_value
