extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value % 6 == 0:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = floor(Global.roll_value*4)
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage"
    if not has_active_roll() or not meets_requirement():
        return "Deal X4 damage"
    var total := apply_target_modifier(modifiers.get_modified_value(floor(Global.roll_value * 4), Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage" % total
