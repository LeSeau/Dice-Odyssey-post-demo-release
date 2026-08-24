extends Relic

# Opens the FIGHT with a bank already going - once, not every turn (Julien, 2026-08-24).
# The per-turn version compounded in long fights; this is a straight head start on turn 1,
# worth most in a deck full of Min gates where it is the difference between needing two
# rolls to arm a card and needing one.
#
# Routed through Global.starting_power_next_turn (Stockpile's field, which dice.gd consumes
# at the top of _on_player_turn_started) rather than adding to roll_value directly. Adding
# directly is a race: player_handler.start_turn() activates relics BEFORE it emits
# player_turn_started, and dice.gd's handler for that signal ASSIGNS roll_value - so a direct
# bump would be silently wiped. `+=` also means it stacks with Stockpile instead of one
# overwriting the other.
#
# battle_started is strictly before the START_OF_COMBAT cascade that opens turn 1, so the
# field is still holding this when dice.gd reads it.

const POWER := 3


func initialize_relic(owner: RelicUI) -> void:
    Events.battle_started.connect(_on_battle_started.bind(owner))


func _on_battle_started(owner: RelicUI) -> void:
    owner.flash()
    Global.starting_power_next_turn += POWER


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.battle_started.is_connected(_on_battle_started):
        Events.battle_started.disconnect(_on_battle_started)
