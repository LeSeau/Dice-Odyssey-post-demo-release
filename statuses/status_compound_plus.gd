class_name CompoundPlusStatus
extends Status

# Compound+ payout: next turn, draw 3 cards and Charge 2 Blue Dice. Draw and charge are
# decoupled here (base CompoundStatus couples them at 2 each via stacks), so Compound+ needs
# its own status class - same reason Marionette+/Steady Hand+/Critical Edge+ each got one.

const CHARGE_SOUND := preload("res://chargedicesound.mp3")


func apply_status(_target: Node) -> void:
    Events.draw_card.emit(3 * stacks)
    Global.blue_dice_current_amount += 2 * stacks
    SFXPlayer.play(CHARGE_SOUND)
    Events.charge_dice_animation.emit()
    Events.dice_amount_changed.emit()
    Events.temporary_dice_added.emit("blue")
    status_applied.emit(self)
