extends Relic

# Every 6th die of the FIGHT, not of the turn (Julien, 2026-08-24). The old per-turn version
# only ever paid on a turn that reached six rolls, which meant it did nothing at all in a
# deck that spreads its rolls across several smaller turns. Counting across the fight makes
# it pay the same total either way, and it keeps paying in long fights.

const POWER_BONUS := 4
const EVERY := 6


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    # Thrown dice advance the count too: Global.report_thrown_die_landed increments
    # fight_dice_rolled before emitting, exactly like dice.gd's real-roll path, so the
    # counter shown here and the trigger below stay in step.
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started.bind(owner))
    _update_counter(owner)


func _on_dice_thrown_landed(dice_type: String, value: int, owner: RelicUI) -> void:
    _on_dice_rolled(dice_type, value, owner)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    _update_counter(owner)
    if Global.fight_dice_rolled == 0 or Global.fight_dice_rolled % EVERY != 0:
        return
    owner.flash()
    Global.roll_value += POWER_BONUS
    Events.change_current_power.emit()


# Cycles 1..6 and pays on the 6, rather than echoing fight_dice_rolled % 6 raw - that would
# show "0" on the very roll that triggers the bonus instead of the "6" the player expects.
func _update_counter(owner: RelicUI) -> void:
    var n: int = Global.fight_dice_rolled
    owner.counter.text = "0" if n == 0 else str(((n - 1) % EVERY) + 1)
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
