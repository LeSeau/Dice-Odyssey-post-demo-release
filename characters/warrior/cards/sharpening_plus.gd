extends Card

const ALL_DICE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech"]

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    var chosen = ALL_DICE_TYPES[randi() % ALL_DICE_TYPES.size()]
    var dice_amount_variable = chosen + "_dice_current_amount"
    Global.set(dice_amount_variable, Global.get(dice_amount_variable) + 1)
    Events.change_current_power.emit()
    Events.charge_dice_animation.emit()
    Events.dice_amount_changed.emit()
    Events.temporary_dice_added.emit(chosen)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Charge a random Dice"
    if not has_active_roll():
        return "Block X. Charge a random Dice"
    return "Block %d. Charge a random Dice" % Global.roll_value
