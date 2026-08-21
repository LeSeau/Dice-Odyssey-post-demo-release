extends Card

# Curse one enemy: for the rest of the FIGHT, every natural 6 you roll hits it. Gated Exact 6
# (Julien, 2026-08-20) - you pay a six to plant the six-curse, which is the tightest gate in
# the pool and the reason this sits at Rare.
#
# Effigy+: same curse, 8 damage per six (carried on effigy_plus.tres::stacks).

const EFFIGY_STATUS = preload("res://statuses/effigy_plus.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if targets.is_empty() or not meets_requirement():
        return
    var status_effect := StatusEffect.new()
    status_effect.status = EFFIGY_STATUS.duplicate()
    status_effect.sound = sound
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
