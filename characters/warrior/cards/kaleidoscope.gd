extends Card

# "This turn, switching Dice types does not reset your Power."
# The one rule change that makes a rainbow turn affordable: normally hopping type wipes the
# chain, which is precisely what pays for Spectrum and the Prismatic Lens. This buys that back
# for a single turn. Deliberately turn-scoped (player_handler clears the flag) - the unlimited
# version of this is a different, much scarier card.
#
# Does NOT reset your own Power on play: resetting would defeat the point of a card whose job
# is to protect the chain.

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Global.keep_power_on_type_change = true
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.reset_charged_card.emit()
