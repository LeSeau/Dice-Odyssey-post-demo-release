extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    # Any 0 counts, not just the Evil die's 0-face - dice.gd floors a
    # Weak-reduced roll at 0 too (max(0, roll_value + next_roll_modifier)), so
    # this already fires off a heavily-weakened low roll. roll_history
    # emptiness disambiguates from the not-yet-rolled state (Card.has_active_roll()).
    if Global.roll_history.is_empty() or Global.roll_value != 0:
        return
    Global.roll_value += 12
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if has_active_roll() and Global.roll_value == 0:
        return "You have 0 Power: gain 12 Power"
    return "If you have rolled Dice but still have 0 Power, gain 12 Power"
