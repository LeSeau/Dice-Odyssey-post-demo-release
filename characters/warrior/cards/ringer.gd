extends Card

# "Min 5: Gain Surge 1 for the rest of combat" - the permanent half of the Surge ladder.
# No surge_expiring here, so SurgeStatus never takes it back; it just accumulates.
# See sleight.gd for the turn-scoped sibling and statuses/surge.gd for the split.

const SURGE_STATUS = preload("res://statuses/surge.tres")
const SURGE_AMOUNT := 1


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
