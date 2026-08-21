extends Card

# Same Celestial carry-over as the base card, larger promise. See compound.gd for why this
# must not emit dice_roll_reset.

const POWER := 8


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    Global.starting_power_next_turn = maxi(Global.starting_power_next_turn, POWER)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.reset_charged_card.emit()
