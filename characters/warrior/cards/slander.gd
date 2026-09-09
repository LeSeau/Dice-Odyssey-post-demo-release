extends Card

# "Shade" - the Slanderer plants this in your DISCARD pile. It never hurts you directly and
# it is never unplayable - the whole tax is what it costs to get rid of it.
#
# Deliberately NOT Celestial: binning it has to cost a roll, or it would be free tempo. Being
# non-Celestial routes it through the same gate every ordinary card uses
# (card_released_state.gd: roll_value > 0 or has_active_roll()), so you cannot play it until you
# have rolled at least once this turn.
#
# apply_effects draws a card, then resets your Power exactly like any ordinary card. The draw
# is what turns this from a card-advantage tax into a TEMPO tax: the Hex replaces itself, so
# the only thing you actually pay is the die plus whatever bank you were sitting on. That is
# still a real decision rather than a flat cost:
#   - bin it right after a single roll (best after a bad one) and you pay about one die;
#   - bin it on top of a long chain and you throw the whole bank away;
#   - leave it in hand and it costs you a card slot for the turn, then cycles back.
# Because a reset also clears roll_history, the card you just drew needs a fresh roll before it
# can be played - so the die is genuinely spent, and the draw can never chain into free value.
#
# Draw is emitted BEFORE the reset. The two touch unrelated state so the order changes nothing
# mechanically; it is written this way so the code reads in the same order as the description.
#
# No SupportEffect here on purpose: that effect exists only to play `sound`, and this card has
# none assigned (an enemy planted it, it is not one of yours).
#
# rarity is NORMAL, not SUPPORT: that flag only drives the red-socket glow and means "does not
# reset your Power", which is not true here. Same flip War Ritual and Compound took.
#
# It still exhausts (card_slander.tres), so paying the toll removes it from the fight for good.
#
# NOT in the draftable pool - it only ever arrives by injection.
#
# Filenames and `id` still say "slander" (the name it shipped under). Card ids are invisible to
# the player and are resolved by resource_path in saves, so they are left alone on a rename -
# same convention as card_rigged/card_second_socket. Only `name` is player-facing.
func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Events.draw_card.emit(1)
    Events.dice_roll_reset.emit()
