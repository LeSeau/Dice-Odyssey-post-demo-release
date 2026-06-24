extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = 6
    block_effect.sound = sound
    block_effect.execute(targets)
    print(targets)
    Events.draw_card.emit(2)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
