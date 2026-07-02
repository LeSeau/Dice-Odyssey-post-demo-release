extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    Events.dice_roll_reset.emit()

func get_dynamic_description(_modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Block ?"
    if not has_active_roll():
        return "Block X"
    return "Block %d" % Global.roll_value
