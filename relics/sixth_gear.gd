extends Relic

# Metronome's big sibling. Metronome pays every 3rd die, which is frequent enough to shove
# your Power off an Exact/Multiple target you were steering toward; this fires ONCE per turn,
# on the 6th die, so it rewards a genuine swarm turn without polluting a precision one.

const POWER_BONUS := 6
const TRIGGER_ON := 6


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    # Thrown dice advance the count too: Global.report_thrown_die_landed increments
    # dice_amount_rolled_this_turn before emitting, exactly like dice.gd's real-roll path,
    # so the counter shown here and the trigger below stay in step.
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started.bind(owner))
    _update_counter(owner)


func _on_dice_thrown_landed(dice_type: String, value: int, owner: RelicUI) -> void:
    _on_dice_rolled(dice_type, value, owner)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    _update_counter(owner)
    # Exactly the 6th, not "every 6th": one payout per turn is the whole point of the design.
    if Global.dice_amount_rolled_this_turn != TRIGGER_ON:
        return
    owner.flash()
    Global.roll_value += POWER_BONUS
    Events.change_current_power.emit()


# Counts up 0..6 and then stops, so the player can see how far off the payout they are.
func _update_counter(owner: RelicUI) -> void:
    var rolled: int = Global.dice_amount_rolled_this_turn
    owner.counter.text = str(mini(rolled, TRIGGER_ON))
    owner.counter.visible = true


func _on_player_turn_started(owner: RelicUI) -> void:
    _update_counter(owner)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
