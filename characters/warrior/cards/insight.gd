extends Card

# Cashes the Power bank in for cards instead of damage (Julien, 2026-09-09). Shared by
# Insight and Insight+ - only requirement_number differs, and meets_requirement() reads it off
# whichever card is being played, so the two cannot drift apart.
#
# The Max gate is TIGHT on purpose (Julien, retuned 2026-09-09 from Max 15 / per 3): at Max 8
# the card is dead the moment a chain gets going, so it is played EARLY in a turn, before the
# bank exists - you draw first and build the chain with the cards you just got, instead of
# cashing out a chain you already built. That is the better shape for a draw card: it feeds
# the turn it is played in. Common on purpose - card draw was the thinnest ladder in the pool
# (two draw cards in seventy-nine before this one), so the fix has to be something you
# actually get offered.
#
# Reads Global.roll_value (the whole banked chain), never last_roll: the reset below is the
# price, and it is the bank that is being spent.

const POWER_PER_CARD := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    # Integer division on purpose: 7 Power draws 3, not 3.5. The leftover is simply spent,
    # which is what keeps "roll one more before cashing out" a real choice.
    var cards := int(Global.roll_value) / POWER_PER_CARD
    if cards > 0:
        Events.draw_card.emit(cards)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Draw 1 card per 2 Power (?)"
    if not has_active_roll() or not meets_requirement():
        return "Draw 1 card per 2 Power"
    return "Draw 1 card per 2 Power (%d)" % (int(Global.roll_value) / POWER_PER_CARD)
