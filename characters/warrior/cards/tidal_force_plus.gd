extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(_effective_damage(), Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _effective_damage() -> int:
    var base := Global.roll_value
    return mini(base, 8) + maxi(0, base - 8) * 2

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Power above 8 counts double"
    if not has_active_roll():
        return "Deal X damage. Power above 8 counts double"
    var total := apply_target_modifier(modifiers.get_modified_value(_effective_damage(), Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d). Power above 8 counts double" % total
