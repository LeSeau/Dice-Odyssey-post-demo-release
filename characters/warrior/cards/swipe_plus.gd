extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()

    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    var active_dice = Global.dice_type
    var dice_amount_variable = active_dice + "_dice_current_amount"

    # Check if the variable exists in Global
    if dice_amount_variable in Global:
        # Update the corresponding amount dynamically

        Events.change_current_power.emit()

        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_amount_changed.emit()

        # load() is still ResourceLoader-cached by path - duplicate so a repeat trigger never
        # hands out the SAME Card object twice (see calculations.gd for the full rationale).
        var oracle_card5 = load("res://characters/warrior/cards/card_scout5.tres").duplicate()
        Events.add_card_to_hand_requested.emit(oracle_card5)
        Events.reset_charged_card.emit()

    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Gain a Scout 5 card"
    if not has_active_roll():
        return "Deal X damage. Gain a Scout 5 card"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d). Gain a Scout 5 card" % total
