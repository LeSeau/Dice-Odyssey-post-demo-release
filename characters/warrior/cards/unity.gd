extends Card

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    if Global.roll_value == 1:
        var block_effect := BlockEffect.new()
        block_effect.amount = 12
        block_effect.sound = sound
        block_effect.execute(targets)
        Events.dice_roll_reset.emit()

        Events.card_type_played.emit("exact")
    Events.reset_charged_card.emit()
