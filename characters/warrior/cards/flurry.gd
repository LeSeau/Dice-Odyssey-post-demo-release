extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    damage_effect.sound = sound  
    var base_damage = Global.roll_value * 2
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal ? damage"
    if not has_active_roll():
        return "Deal X2 damage"
    var total := modifiers.get_modified_value(Global.roll_value * 2, Modifier.Type.DMG_DEALT)
    return "Deal %d damage" % total
