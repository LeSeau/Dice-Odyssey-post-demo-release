extends Card

# Investment: next turn, draw 2 extra cards and Charge 2 Blue Dice (CompoundStatus pays
# out at the next turn start). Resets your Power (Julien, 2026-07-20).

const COMPOUND_STATUS = preload("res://statuses/status_compound.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    status_effect.status = COMPOUND_STATUS.duplicate()
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
