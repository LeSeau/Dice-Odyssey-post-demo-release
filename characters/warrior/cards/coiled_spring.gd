extends Card

# Wind up: next turn, your first Dice roll counts triple towards your Power (see
# CoiledSpringStatus - arms at the next turn start, consumes on the first roll after).
# Resets your Power (Julien, 2026-07-28). Exhausts. Shared by Coiled Spring+.

const SPRING_STATUS = preload("res://statuses/status_coiled_spring.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    status_effect.status = SPRING_STATUS.duplicate()
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
