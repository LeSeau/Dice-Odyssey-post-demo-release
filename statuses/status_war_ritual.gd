class_name WarRitualStatus
extends Status

# One-shot next-turn Charge: `stacks` = how many random Dice arrive (2 per card play,
# INTENSITY-stacking if replayed the same turn). Fires at START_OF_TURN, which lands
# AFTER dice_interface's per-turn pool refill (the refill runs synchronously on
# player_turn_started; statuses apply on the deferred relic->status tween chain), so the
# charged dice are never wiped by the refill.

const CHARGE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]
const CHARGE_SOUND := preload("res://chargedicesound.mp3")


func apply_status(_target: Node) -> void:
    for i in stacks:
        var chosen: String = CHARGE_TYPES[randi() % CHARGE_TYPES.size()]
        var prop := chosen + "_dice_current_amount"
        Global.set(prop, int(Global.get(prop)) + 1)
        Events.temporary_dice_added.emit(chosen)
        # One typed emit per die - each delivery flies in its own type's color (the reveal).
        # The launch sound lives with the delivery now (dice_interface), no manual play.
        Events.dice_charged.emit(chosen, 1)
    Events.dice_amount_changed.emit()
    status_applied.emit(self)
