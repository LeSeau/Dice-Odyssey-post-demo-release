extends Card

# "Min 5: Gain Loaded 1 for the rest of combat" - the permanent half of the Loaded ladder.
# No loaded_expiring here, so LoadedStatus never takes it back; it just accumulates.
# See sleight.gd for the turn-scoped sibling and statuses/loaded.gd for the split.

const LOADED_STATUS = preload("res://statuses/loaded.tres")
const LOADED_AMOUNT := 1


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.loaded_amount += LOADED_AMOUNT
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    var loaded := LOADED_STATUS.duplicate()
    loaded.stacks = LOADED_AMOUNT
    status_effect.status = loaded
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
