extends Card

# IN-HAND PASSIVE: while this sits in your hand, every Red roll gains 3 Power.
# Julien's idea, and it opens a whole new card class - a card that does something WITHOUT
# being played. The tension only exists because it also has a real play effect: hold it as an
# aura, or spend it for the dice. Global.in_hand_roll_bonus() reads the live hand.

const CHARGE_COUNT := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Global.red_dice_current_amount += CHARGE_COUNT
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit("red", CHARGE_COUNT)
    Events.temporary_dice_added.emit("red")
    Events.reset_charged_card.emit()
