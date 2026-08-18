extends Card

# IN-HAND PASSIVE, and the "cursed blessing" of the family: while it clogs your hand it grants
# Loaded 1 (every roll gains 1 Power), and it can never be played. It costs you a card slot
# every turn you draw it - that IS the price.
#
# Deviation from the original spec ("exhausts at end of turn"): it discards normally instead,
# so it cycles back. That makes it a permanent small buff you keep re-drawing rather than a
# one-shot, which reads better with the hand-slot cost. Flagged for Julien.
#
# would_no_op_now() is what the pick-up refusal in card_clicked_state.gd checks, so trying to
# drag this gives the standard shake + message instead of silently doing nothing.


func would_no_op_now() -> bool:
    return true


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
    # Unreachable in normal play (would_no_op_now blocks the drag), but a no-op rather than an
    # error if some future path plays it anyway.
    Events.reset_charged_card.emit()
