extends Card

# Wind up: next turn, your first Dice roll counts triple towards your Power (see
# CoiledSpringStatus - arms at the next turn start, consumes on the first roll after).
# Celestial + SUPPORT flag: playable at zero resources, never resets your Power. Exhausts.

const SPRING_STATUS = preload("res://statuses/status_coiled_spring.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    status_effect.status = SPRING_STATUS.duplicate()
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.reset_charged_card.emit()
