extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    var active_dice = Global.dice_type
    var dice_amount_variable = active_dice + "_dice_current_amount"
    Global.set(dice_amount_variable, Global.get(dice_amount_variable) + 1)
    Events.dice_charged.emit(active_dice, 1)
    Events.temporary_dice_added.emit(active_dice)
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value
    Events.reset_charged_card.emit()
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)

    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Charge 1"
    if not has_active_roll():
        return "Deal X damage. Charge 1"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d). Charge 1" % total
