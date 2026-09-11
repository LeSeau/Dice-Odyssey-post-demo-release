extends Card

# "Remove the 2 lowest faces from Red Dice this combat" - Red becomes 3/4/5/6.
# Buffed from one face to two on 2026-09-06 and promoted to Rare in the same pass.
#
# SHARED WITH GRINDSTONE+ (Julien, 2026-09-06): both versions trim exactly two faces, and
# the upgrade is purely a looser gate - Min 6 on the base, Min 4 on the "+". meets_requirement()
# reads each card's own .tres, so one script serves both and they cannot drift apart.
# forge_plus.gd is now orphaned on disk.
# The quiet payoff: Kamikaze's "if you roll a 1, lose 6 HP instead" clause stops existing.
#
# Computed from the die's CURRENT effective faces (Global.current_face_values) rather than the
# printed ones, so it stacks correctly with an infusion or a previous trim; the result is
# stored as the new fight-scoped override.

const TRIM_COUNT := 2
const DICE_TYPE := "red"
const FORGE_STATUS = preload("res://statuses/status_forge.tres")


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
        status_effect.status = FORGE_STATUS.duplicate()
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
