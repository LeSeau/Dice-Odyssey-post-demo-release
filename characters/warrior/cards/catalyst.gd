extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    var dice_amount_to_return = Global.roll_history.size()

    var property_name := "%s_dice_current_amount" % Global.dice_type
    Global.set(property_name, Global.get(property_name) + dice_amount_to_return)

    var active_dice = Global.dice_type
    var dice_amount_variable = active_dice + "_dice_current_amount"
    if dice_amount_variable in Global:
        var current_amount = Global.get(dice_amount_variable)
        Global.set(dice_amount_variable, current_amount + 1)
        Events.dice_charged.emit(active_dice, 1)

    Events.change_current_power.emit()

    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.refuel_happened.emit(Global.roll_value)
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
    Events.reset_charged_card.emit()
