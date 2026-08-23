extends Relic

# Rewards chain LENGTH, which nothing else does - Crown and Metronome both count dice
# regardless of whether they were part of one unbroken run. Global.roll_history is exactly
# that chain: it is cleared on a Power reset and on a dice-type switch, so its size is the
# number of consecutive rolls banked on the current type.
#
# Thrown dice deliberately do NOT count: they never join the Power chain (they don't touch
# roll_history), so counting them would contradict the chain this relic is reading.

const CHAIN_LENGTH := 4

var triggered_this_turn := false


func initialize_relic(owner: RelicUI) -> void:
    triggered_this_turn = false
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if triggered_this_turn or Global.roll_history.size() < CHAIN_LENGTH:
        return
    triggered_this_turn = true
    owner.flash()
    # Charges the die you are actually chaining on, not a random one - the reward for
    # committing to a type should feed that commitment.
    var dice_type: String = Global.dice_type
    var amount_field := dice_type + "_dice_current_amount"
    Global.set(amount_field, Global.get(amount_field) + 1)
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit(dice_type, 1)
    Events.temporary_dice_added.emit(dice_type)


func _on_player_turn_started() -> void:
    triggered_this_turn = false


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
