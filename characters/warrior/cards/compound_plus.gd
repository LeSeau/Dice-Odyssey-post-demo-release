extends Card

# Compound+ : next turn, draw 3 cards and Charge 2 Blue Dice (base draws 2). Draw and charge
# decouple here (base status couples them 2/2), so this uses its own CompoundPlusStatus.

const COMPOUND_PLUS_STATUS = preload("res://statuses/status_compound_plus.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    status_effect.status = COMPOUND_PLUS_STATUS.duplicate()
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
