extends Card

# War Ritual+ : Charge 3 random Dice next turn instead of 2 (base war_ritual.gd). The count
# lives in the status's stacks, bumped here before it's applied.

const RITUAL_STATUS = preload("res://statuses/status_war_ritual.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    var ritual: Status = RITUAL_STATUS.duplicate()
    ritual.stacks = 3
    status_effect.status = ritual
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this arms next turn, and nothing about it reads this turn,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
func plays_at_zero_power() -> bool:
    return true
