extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    var block_effect := BlockEffect.new()
    block_effect.amount = 8
    block_effect.sound = sound
    block_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
    Events.force_end_turn.emit()

func _on_dice_rolled():
    print("adding dice to damage")
