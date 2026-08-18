extends Card

# Grafts Ricochet's reroll onto Blue for the rest of the fight. dice.gd's _type_can_reroll()
# is the single gate - it already drives the reroll button's visibility, the per-roll snapshot
# capture and the allowance check, so adding a type here lights all three up at once.
#
# This deliberately opens "any die can borrow another die's ability" as a design family; the
# act-2 infusions do the same thing permanently, so a fight-scoped version teaches that
# fantasy early.

const DICE_TYPE := "blue"


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.reroll_types[DICE_TYPE] = true
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    status_effect.status = preload("res://statuses/status_quicksilver.tres").duplicate()
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
