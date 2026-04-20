extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.draw_card.emit(3)
    if Global.roll_value % 2 != 0: 
        var block_effect := BlockEffect.new()
        block_effect.amount = Global.roll_value
        block_effect.sound = sound
        block_effect.execute(targets)

    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
