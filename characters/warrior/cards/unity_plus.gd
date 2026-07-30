extends Card

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    if meets_requirement():
        var block_effect := BlockEffect.new()
        block_effect.amount = 18
        block_effect.sound = sound
        block_effect.execute(targets)
        Events.dice_roll_reset.emit()

        Events.card_type_played.emit("exact")
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?"
    if meets_requirement():
        return "Block 18"
    return "Gain X18 Block"
