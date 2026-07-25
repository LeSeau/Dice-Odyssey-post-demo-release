extends Card

# Low Roller+ : 15 - X instead of 12 - X (base low_roller.gd). Inverted scaling, bigger ceiling.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty() or not has_active_roll():
        Events.reset_charged_card.emit()
        return
    var base := maxi(0, 15 - int(Global.roll_value))
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage"
    if not has_active_roll():
        return "Deal 15 - X damage"
    var base := maxi(0, 15 - int(Global.roll_value))
    var total := apply_target_modifier(modifiers.get_modified_value(base, Modifier.Type.DMG_DEALT), target)
    return "Deal 15 - X damage (%d)" % total
