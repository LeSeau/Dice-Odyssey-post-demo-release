extends Card

# "Min 6: Gain Surge 2 for the rest of combat" - the permanent half of the Surge ladder,
# doubled. Separate script from ringer.gd only because SURGE_AMOUNT is a const: a Card has no
# payload field the way a Status has `stacks`, so the two amounts cannot share one script.
# ⚠️ Keep the body in step with ringer.gd - only the constant differs.
#
# No surge_expiring here, so SurgeStatus never takes it back; it just accumulates. See
# sleight.gd for the turn-scoped sibling and statuses/surge.gd for the split.

const SURGE_STATUS = preload("res://statuses/surge.tres")
const SURGE_AMOUNT := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.surge_amount += SURGE_AMOUNT
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    var surge := SURGE_STATUS.duplicate()
    surge.stacks = SURGE_AMOUNT
    status_effect.status = surge
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
