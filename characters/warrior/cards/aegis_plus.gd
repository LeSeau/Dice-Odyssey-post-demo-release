extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value % 6 == 0:
        var block_effect := BlockEffect.new()
        block_effect.amount = Global.roll_value*4
        block_effect.sound = sound
        block_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Block ?"
    if not has_active_roll() or not meets_requirement():
        return "Block X4"
    return "Block %d" % (Global.roll_value * 4)
