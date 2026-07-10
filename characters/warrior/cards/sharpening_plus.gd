extends Card

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:

    if Global.roll_value >= 4:
        var block_effect := BlockEffect.new()
        block_effect.amount = Global.roll_value
        block_effect.sound = sound
        block_effect.execute(targets)
        var active_dice = Global.dice_type
        var dice_amount_variable = active_dice + "_dice_current_amount"
        Global.set(dice_amount_variable, Global.get(dice_amount_variable) + 1)
        Events.change_current_power.emit()
        Events.charge_dice_animation.emit()
        Events.dice_amount_changed.emit()
        Events.temporary_dice_added.emit(active_dice)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Charge 1"
    if not has_active_roll() or not meets_requirement():
        return "Block X. Charge 1"
    return "Block %d. Charge 1" % Global.roll_value
