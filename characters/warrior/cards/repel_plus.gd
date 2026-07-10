extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.draw_card.emit(3)
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Draw 3 cards"
    if not has_active_roll():
        return "Block X. Draw 3 cards"
    return "Block %d. Draw 3 cards" % Global.roll_value
