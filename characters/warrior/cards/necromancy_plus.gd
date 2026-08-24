extends Card

# Upgrade of necromancy.gd: same Charge 2, but the gate loosens Max 3 -> Max 5 (Julien) and
# the card draw is gone - the upgrade widens the window instead of stacking more value on it.

const CHARGE_COUNT := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.evil_dice_current_amount += CHARGE_COUNT
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit("evil", CHARGE_COUNT)
    Events.temporary_dice_added.emit("evil")
    Events.reset_charged_card.emit()
