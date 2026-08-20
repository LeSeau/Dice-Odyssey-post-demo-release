extends Card

# Pure setup (Julien, 2026-08-20): no damage of its own, just a long Exposed on the whole
# board. Exposed's number is DURATION, not magnitude - it is always +50% damage taken, and 5
# means it survives to the end of most fights. That is the point: Corrode is the card you
# play BEFORE the turn that kills, and it is dead weight in a two-turn trash fight.

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const EXPOSED_DURATION := 5


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if not meets_requirement():
        return
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    var exposed: Status = EXPOSED_STATUS.duplicate()
    exposed.duration = EXPOSED_DURATION
    status_effect.status = exposed
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
