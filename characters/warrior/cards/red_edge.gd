extends Card

# "Remove the 2 lowest faces from Red Dice this combat" - Red becomes 3/4/5/6.
# The quiet payoff: Kamikaze's "if you roll a 1, lose 6 HP instead" clause stops existing.
#
# Computed from the die's CURRENT effective faces (Global.current_face_values) rather than the
# printed ones, so it stacks correctly with an infusion or a previous trim; the result is
# stored as the new fight-scoped override.

const TRIM_COUNT := 2
const DICE_TYPE := "red"


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    var values: Array = Global.current_face_values(DICE_TYPE).duplicate()
    values.sort()
    # Never trim the die out of existence - always leave at least one face to roll.
    var trim: int = mini(TRIM_COUNT, maxi(0, values.size() - 1))
    if trim > 0:
        values = values.slice(trim)
        Global.face_overrides[DICE_TYPE] = values
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
