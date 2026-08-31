extends Relic

# Opening-hand width, the one thing Magic Sleeve (+1 card EVERY turn) does not give: this is
# front-loaded instead of compounding, so it buys a stronger turn 1 - the turn where a bad
# hand costs the most, because there is no discard pile to have cycled yet.
#
# Writes a Global rather than emitting draw_card, and that is load-bearing: START_OF_COMBAT
# relics run BEFORE player_handler.start_battle(), so `character` (and its draw pile) does not
# exist yet and a draw here would hit a null. player_handler folds the number into the opening
# deal instead and zeroes it, which also keeps the whole hand on ONE tween - so
# player_hand_drawn still fires at the true end of the deal rather than mid-way through it.

const EXTRA_CARDS := 2


func activate_relic(owner: RelicUI) -> void:
    owner.flash()
    Global.bonus_cards_first_hand += EXTRA_CARDS


func deactivate_relic(_owner: RelicUI) -> void:
    # Only matters if the relic is somehow removed between the cascade and the opening deal;
    # player_handler clears the field on consumption for the ordinary path.
    Global.bonus_cards_first_hand = 0
