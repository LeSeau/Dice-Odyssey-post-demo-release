class_name DicelordGiftStatus
extends Status

# Blessing engine (Gift From The Dicelord): Charge 1 random Dice at the start of every
# turn for the rest of the combat. Permanent (can_expire=false), no stacks badge - same
# visual convention as the other Blessing statuses. First payout arrives at the start of
# the NEXT turn after playing the card, same cadence as Steady Hand/Cogwork.

const CHARGE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]
const CHARGE_SOUND := preload("res://chargedicesound.mp3")


func apply_status(_target: Node) -> void:
    var chosen: String = CHARGE_TYPES[randi() % CHARGE_TYPES.size()]
    var prop := chosen + "_dice_current_amount"
    Global.set(prop, int(Global.get(prop)) + 1)
    # The launch sound lives with the delivery now (dice_interface), no manual play.
    Events.dice_charged.emit(chosen, 1)
    Events.dice_amount_changed.emit()
    Events.temporary_dice_added.emit(chosen)
    status_applied.emit(self)
