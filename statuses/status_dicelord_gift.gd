class_name DicelordGiftStatus
extends Status

# Blessing engine (Gift From The Dicelord): Charge 1 random Dice at the start of every
# turn for the rest of the combat. Permanent (can_expire=false), no stacks badge - same
# visual convention as the other Blessing statuses. First payout arrives at the start of
# the NEXT turn after playing the card, same cadence as Steady Hand/Cogwork.

const CHARGE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]
const CHARGE_SOUND := preload("res://chargedicesound.mp3")


# How many dice to charge rides on `stacks` so the base status (1) and
# status_dicelord_gift_plus.tres (2) share this script. stack_type is NONE on both, so the
# number is a payload rather than a badge - the same trick Effigy uses.
func apply_status(_target: Node) -> void:
    for _i in range(maxi(stacks, 1)):
        var chosen: String = CHARGE_TYPES[randi() % CHARGE_TYPES.size()]
        var prop := chosen + "_dice_current_amount"
        Global.set(prop, int(Global.get(prop)) + 1)
        # The launch sound lives with the delivery now (dice_interface), no manual play.
        Events.dice_charged.emit(chosen, 1)
        Events.temporary_dice_added.emit(chosen)
    Events.dice_amount_changed.emit()
    status_applied.emit(self)
