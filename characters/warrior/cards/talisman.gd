extends Card

# IN-HAND PASSIVE, and now a member of the sixes family alongside Jackpot and Effigy: while
# it sits in your hand, every natural 6 you roll grants Block. It can never be played
# (Julien, 2026-08-20) - holding it IS the effect, so there is no second mode to spend.
#
# The Block itself is granted by dice.gd at the same `last_roll == 6` check Jackpot and
# Effigy already key off, so all three agree on what a "6" is: the face actually rolled,
# never a Boosted or Surge 5->6. The amount lives in Global.TALISMAN_SIX_BLOCK.
#
# would_no_op_now() is what the pick-up refusal in card_clicked_state.gd checks, so dragging
# this gives the standard shake + message instead of silently doing nothing.


func would_no_op_now() -> bool:
    return true


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
    # Unreachable in normal play (would_no_op_now blocks the drag); a no-op rather than an
    # error if some future path plays it anyway.
    Events.reset_charged_card.emit()
