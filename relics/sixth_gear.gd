extends Relic

# Every 8th die of the FIGHT, not of the turn (Julien, 2026-08-24). The old per-turn version
# only ever paid on a turn that reached six rolls, which meant it did nothing at all in a
# deck that spreads its rolls across several smaller turns. Counting across the fight makes
# it pay the same total either way, and it keeps paying in long fights.
#
# Retuned 2026-08-28 (Julien): 6 dice for 4 Power -> 8 dice for 6 Power. Same shape, rarer and
# chunkier - the payout is now worth planning a turn around instead of quietly topping up a roll.

const POWER_BONUS := 6
const EVERY := 8


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started.bind(owner))
    _update_counter(owner)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    _update_counter(owner)
    if Global.fight_dice_rolled == 0 or Global.fight_dice_rolled % EVERY != 0:
        return
    owner.flash()
    Global.roll_value += POWER_BONUS
    Events.change_current_power.emit()


# Cycles 1..EVERY and pays on the last one, rather than echoing fight_dice_rolled % EVERY raw -
# that would show "0" on the very roll that triggers the bonus instead of the "8" the player
# expects.
func _update_counter(owner: RelicUI) -> void:
    var n: int = Global.fight_dice_rolled
    owner.counter.text = "0" if n == 0 else str(((n - 1) % EVERY) + 1)
    owner.counter.visible = true


func _on_player_turn_started(owner: RelicUI) -> void:
    _update_counter(owner)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
