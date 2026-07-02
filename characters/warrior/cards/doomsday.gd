extends Card



func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value == 13:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value * 4
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal ? damage"
    if Global.roll_value == 13:
        var total := modifiers.get_modified_value(Global.roll_value * 4, Modifier.Type.DMG_DEALT)
        return "Deal %d damage" % total
    return "Deal X4 damage"

