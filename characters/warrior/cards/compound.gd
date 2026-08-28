extends Card

# Celestial investment: costs nothing now, hands you a head start next turn.
#
# Celestial here is STRUCTURAL, not flavour (Julien, 2026-08-20). A non-Celestial card is
# refused before the turn's first roll, and every Power reset clears roll_history - so the
# only legal window to play a *resetting* Compound would have been "while holding a bank",
# which it would then have thrown away for less than it gave back. Celestial removes both the
# gate and the reset, and the card becomes what it says: free Power, next turn.
#
# maxi() rather than += mirrors Stockpile: several carry-over promises in one turn resolve to
# the largest instead of silently stacking. dice.gd consumes the value once, at turn start.

const POWER := 5


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var before: int = Global.starting_power_next_turn
    Global.starting_power_next_turn = maxi(before, POWER)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    # The payout itself lives in dice.gd, so without this the card would leave nothing
    # on screen. Pass the DELTA, not POWER - see CompoundStatus.show_promise().
    CompoundStatus.show_promise(targets, Global.starting_power_next_turn - before)
    Events.reset_charged_card.emit()
