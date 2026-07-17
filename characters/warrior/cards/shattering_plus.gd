extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6:
        var block_effect := BlockEffect.new()
        block_effect.amount = Global.roll_value
        block_effect.sound = sound
        block_effect.execute(targets)
        Global.green_dice_current_amount+=4
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit("green")
    Events.reset_charged_card.emit()

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Charge 4 Pixie Dice"
    if not has_active_roll() or not meets_requirement():
        return "Block X. Charge 4 Pixie Dice"
    return "Block %d. Charge 4 Pixie Dice" % Global.roll_value
