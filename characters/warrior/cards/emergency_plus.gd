extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = 13
    block_effect.sound = sound
    block_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
    Events.force_end_turn.emit()

func _on_dice_rolled():
    print("adding dice to damage")

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this grants a flat Block amount,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
func plays_at_zero_power() -> bool:
    return true
