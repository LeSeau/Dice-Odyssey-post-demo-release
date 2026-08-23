extends Relic

# Golem's defining trait, handed to every type you own. The tempo question it creates is the
# whole point: holding dice back stops being a waste, so "spend everything every turn" is no
# longer automatically right.
#
# Reuses the stash the "Keep your Dice" card already built (dice_interface captures leftovers
# on player_turn_ended and adds them to the next refill) rather than a second mechanism, so
# the two cannot double-bank. Golem itself is excluded from that stash - it already carries.
#
# Uncapped, like Golem's own carryover: the cost of hoarding is the tempo you gave up. The
# enemy ramps are what price stalling, not a cap.


func initialize_relic(_owner: RelicUI) -> void:
    Global.keep_all_dice_always = true


func deactivate_relic(_owner: RelicUI) -> void:
    Global.keep_all_dice_always = false
