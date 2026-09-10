extends Card

# Next turn, Charge 2 random Dice (WarRitualStatus pays out at the next turn start,
# after the normal per-turn refill). Resets your Power (Julien, 2026-07-20).

const RITUAL_STATUS = preload("res://statuses/status_war_ritual.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    status_effect.status = RITUAL_STATUS.duplicate()
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this arms next turn, and nothing about it reads this turn,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
func plays_at_zero_power() -> bool:
    return true
