class_name CompoundStatus
extends Status

# "Next turn, draw 2 cards and Charge 2 Blue Dice" - one-shot START_OF_TURN payout.
# `stacks` = times the card was played before this turn (INTENSITY), so two Compounds
# pay out 4 cards + 4 Blue Dice together. Statuses apply BEFORE the normal hand deal
# (_on_statuses_applied is what triggers draw_cards), so the bonus cards simply join
# this turn's hand.

const CHARGE_SOUND := preload("res://chargedicesound.mp3")


func apply_status(_target: Node) -> void:
    Events.draw_card.emit(2 * stacks)
    Global.blue_dice_current_amount += 2 * stacks
    SFXPlayer.play(CHARGE_SOUND)
    Events.charge_dice_animation.emit()
    Events.dice_amount_changed.emit()
    Events.temporary_dice_added.emit("blue")
    status_applied.emit(self)
