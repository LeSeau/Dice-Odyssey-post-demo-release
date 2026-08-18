extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if Global.roll_value % 2 == 0:

        var block_effect := BlockEffect.new()
        block_effect.amount = Global.roll_value
        block_effect.sound = sound
        block_effect.execute(targets)

        Global.giant_dice_current_amount += 1
        Events.dice_amount_changed.emit()
        Events.dice_charged.emit("giant", 1)
        Events.temporary_dice_added.emit("giant")

        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Charge a Giant Dice"
    if not has_active_roll() or not meets_requirement():
        return "Gain X Block. Charge a Giant Dice"
    return "Gain X Block (%d). Charge a Giant Dice" % Global.roll_value
