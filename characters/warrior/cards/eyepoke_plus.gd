extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.draw_card.emit(4)
    var damage_effect := DamageEffect.new()
    var base_damage = floor(Global.roll_value)
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Draw 4 cards"
    if not has_active_roll():
        return "Deal X damage. Draw 4 cards"
    var total := apply_target_modifier(modifiers.get_modified_value(floor(Global.roll_value), Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d). Draw 4 cards" % total
