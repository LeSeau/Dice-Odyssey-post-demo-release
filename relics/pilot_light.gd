extends Relic

# Every turn opens with a small bank already going. Worth more than it looks in a deck full
# of Min gates: it is the difference between needing two rolls to arm a card and needing one.
#
# Routed through Global.starting_power_next_turn (Stockpile's field, which dice.gd consumes
# at the top of _on_player_turn_started) rather than adding to roll_value directly. Adding
# directly is a race: player_handler.start_turn() activates relics BEFORE it emits
# player_turn_started, and dice.gd's handler for that signal ASSIGNS roll_value - so a direct
# bump would be silently wiped. `+=` also means it stacks with Stockpile instead of one
# overwriting the other.

const POWER := 2


func initialize_relic(owner: RelicUI) -> void:
    # Both entry points are strictly before dice.gd consumes the field, so neither can be
    # eaten: battle_started fires before the START_OF_COMBAT cascade that starts turn 1, and
    # turn_ended is a whole turn ahead of the next turn's start.
    Events.battle_started.connect(_on_battle_started.bind(owner))
    Events.player_turn_ended.connect(_on_player_turn_ended.bind(owner))


func _on_battle_started(owner: RelicUI) -> void:
    owner.flash()
    Global.starting_power_next_turn += POWER


func _on_player_turn_ended(owner: RelicUI) -> void:
    owner.flash()
    Global.starting_power_next_turn += POWER


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.battle_started.is_connected(_on_battle_started):
        Events.battle_started.disconnect(_on_battle_started)
    if Events.player_turn_ended.is_connected(_on_player_turn_ended):
        Events.player_turn_ended.disconnect(_on_player_turn_ended)
