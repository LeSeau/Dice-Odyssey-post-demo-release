extends Card

# "End your turn. Keep your Dice for next turn." Emergency's dice-economy sibling.
# Fair now in a way it would not have been before the anti-stall enemy pass: skipping a turn
# has a real price against ramping enemies.
#
# The stash/restore lives in dice_interface (turn-end capture + refill), mirroring Golem's
# carryover; Golem is excluded there so the two can't double up.

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Global.keep_all_dice_next_turn = true
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
    Events.force_end_turn.emit()
