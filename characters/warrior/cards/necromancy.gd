extends Card

# Max 3: Charge 2 Evil Dice (Julien, 2026-08-16). Was an ungated "Charge 1" - a whole card slot
# for a single die, so you routinely ended the turn with dice left and only four cards for
# blue/red/evil. The Max gate makes it the Low Roll -> Evil bridge: a bad roll is what pays for
# the sixes engine.

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
