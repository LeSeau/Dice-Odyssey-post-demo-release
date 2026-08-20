extends Card

# Bigger aura, same rule: unplayable, effect lives in Global.in_hand_roll_bonus().
# IN-HAND PASSIVE: while this sits in your hand, every Red roll gains bonus Power. It can
# never be played (Julien, 2026-08-20) - the aura is the whole card, and the old "spend it
# for 2 Red Dice" mode was a way to delete your own buff.
#
# The bonus itself lives in Global.in_hand_roll_bonus(), which reads the live Hand, so the
# aura switches off the instant the card is played, discarded or swept - no sync needed.
# Same figure as the Blood Sword relic, and the two stack.


func would_no_op_now() -> bool:
    return true


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
