extends Card

# Wind up: next turn, your first Dice roll counts triple towards your Power (see
# CoiledSpringStatus - arms at the next turn start, consumes on the first roll after).
# Resets your Power (Julien, 2026-07-28). Exhausts. Shared by Buzzer Shot+.

const SPRING_STATUS = preload("res://statuses/status_coiled_spring.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    status_effect.status = SPRING_STATUS.duplicate()
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this arms next turn, and nothing about it reads this turn,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
# Shared by Buzzer Shot and Buzzer Shot+.
func plays_at_zero_power() -> bool:
    return true
