extends Card



func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if meets_requirement():
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value * 6
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage"
    if meets_requirement():
        var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value * 6, Modifier.Type.DMG_DEALT), target)
        return "Deal X6 damage (%d)" % total
    return "Deal X6 damage"
