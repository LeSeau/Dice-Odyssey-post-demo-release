extends Card

# Same trade as the base card, one more die. See electrify.gd.
# A burst of Ricochet dice - and Ricochet's whole identity is the reroll, so this is really
# "buy N extra chances at a good face".
#
# The Depleted downside was dropped (Julien, 2026-08-20): Depleted has no mechanical effect
# yet, so it was showing the player a badge that cost them nothing - a fake price. Charge
# count came down 3 -> 2 at the same time, and the card moved to Uncommon.

const CHARGE_COUNT := 3
const DICE_TYPE := "odd"


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Global.odd_dice_current_amount += CHARGE_COUNT
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit(DICE_TYPE, CHARGE_COUNT)
    Events.temporary_dice_added.emit(DICE_TYPE)
    Events.reset_charged_card.emit()
