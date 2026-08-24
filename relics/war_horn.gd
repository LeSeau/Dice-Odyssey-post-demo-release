extends Relic

# Was a free Scout 3 card; now an extra Red Dice on turn 1 (Julien, 2026-08-24). Red is the
# gamble die - you socket a card and then roll - so an extra one on the opening turn is a
# free swing at a big first hit rather than information about a roll you have not made yet.
#
# Mirrors Dice Bag exactly: bonus_amount is the one-turn channel (dice_interface.gd refills
# current = max + bonus at the top of each turn, then zeroes bonus), so this lands on turn 1
# only and never touches the permanent loadout.


func activate_relic(owner: RelicUI) -> void:
    owner.flash()
    Global.red_dice_bonus_amount += 1
