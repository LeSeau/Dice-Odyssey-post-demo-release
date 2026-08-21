extends Card

# Red Edge+: trims the two lowest faces instead of one, behind a Min 4 gate.

# "Remove the 2 lowest faces from Red Dice this combat" - Red becomes 3/4/5/6.
# The quiet payoff: Kamikaze's "if you roll a 1, lose 6 HP instead" clause stops existing.
#
# Computed from the die's CURRENT effective faces (Global.current_face_values) rather than the
# printed ones, so it stacks correctly with an infusion or a previous trim; the result is
# stored as the new fight-scoped override.

const TRIM_COUNT := 2
const DICE_TYPE := "red"
const RED_EDGE_STATUS = preload("res://statuses/status_red_edge.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    var values: Array = Global.current_face_values(DICE_TYPE).duplicate()
    values.sort()
    # Never trim the die out of existence - always leave at least one face to roll.
    var trim: int = mini(TRIM_COUNT, maxi(0, values.size() - 1))
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    if trim > 0:
        values = values.slice(trim)
        Global.face_overrides[DICE_TYPE] = values
        # Same invisible-rule fix as Counterfeit (2026-08-19): the trim lasts the whole
        # combat, so it needs a badge. Inside the guard, so a play that trimmed nothing
        # never shows one. No sound on the StatusEffect - SupportEffect already played it.
        var status_effect := StatusEffect.new()
        status_effect.status = RED_EDGE_STATUS.duplicate()
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
