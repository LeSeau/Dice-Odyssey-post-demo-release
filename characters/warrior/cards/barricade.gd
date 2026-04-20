extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 5:
        var block_effect := BlockEffect.new()
        block_effect.amount = 12
        block_effect.sound = sound
        block_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.reset_charged_card.emit()
