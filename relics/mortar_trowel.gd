extends Relic

# Block stops being strictly use-it-or-lose-it. Capped low on purpose: the cap is what keeps
# this from turning into a turtle engine alongside Runic Shield, which already pays 3 Block
# per unspent die every turn.
#
# The carry itself happens in player_handler.start_turn(), which has to capture the old value
# BEFORE it wipes it - relics activate later in that same function (and via a tween, so a
# frame later again), by which point the number is already gone.

const CARRYOVER_CAP := 5


func initialize_relic(_owner: RelicUI) -> void:
    Global.block_carryover_cap = CARRYOVER_CAP


func deactivate_relic(_owner: RelicUI) -> void:
    Global.block_carryover_cap = 0
