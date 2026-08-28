extends Card

# Same Celestial carry-over as the base card, larger promise. See compound.gd for why this
# must not emit dice_roll_reset.

const POWER := 8


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
