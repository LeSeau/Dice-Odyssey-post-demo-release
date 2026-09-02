extends Card

# The Slanderer plants this in your DISCARD pile. It never hurts you directly and it is never
# unplayable - the whole tax is what it costs to get rid of it.
#
# Deliberately NOT Celestial: binning it has to cost a roll, or it would be free tempo. Being
# non-Celestial routes it through the same gate every ordinary card uses
# (card_released_state.gd: roll_value > 0 or has_active_roll()), so you cannot play it until you
# have rolled at least once this turn.
#
# apply_effects does nothing EXCEPT reset your Power, exactly like any ordinary card. That is
# where the pain lives, and it is a real decision rather than a flat cost:
#   - bin it right after a single roll (best after a bad one) and you pay about one die;
#   - bin it on top of a long chain and you throw the whole bank away;
#   - leave it in hand and it costs you a card slot for the turn, then cycles back.
# Because a reset also clears roll_history, the next card you play needs a fresh roll too - so
# the die is genuinely spent, not just borrowed.
#
# rarity is NORMAL, not SUPPORT: that flag only drives the red-socket glow and means "does not
# reset your Power", which stopped being true here. Same flip War Ritual and Compound took.
#
# It still exhausts (card_slander.tres), so paying the toll removes it from the fight for good.
#
# NOT in the draftable pool - it only ever arrives by injection.
func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Events.dice_roll_reset.emit()
