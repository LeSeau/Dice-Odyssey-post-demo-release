extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value
    if Global.dice_type == "red":
        base_damage+=6
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage"
    if not has_active_roll():
        return "Deal X damage"
    var base := Global.roll_value
    if Global.dice_type == "red":
        base += 6
    var total := apply_target_modifier(modifiers.get_modified_value(base, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage" % total
