extends Card

# The pool's big gated AoE now that Fumigation is cut (Julien, 2026-08-20): X2 to every body,
# still behind Min 10 so it stays a late-turn payoff rather than an opener. The Exposed rider
# moved to the upgrade.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if not meets_requirement():
        return
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value * 2, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage to ALL enemies"
    if not has_active_roll() or not meets_requirement():
        return "Deal X2 damage to ALL enemies"
    var total := apply_target_modifier(
        modifiers.get_modified_value(Global.roll_value * 2, Modifier.Type.DMG_DEALT), target)
    return "Deal X2 damage (%d) to ALL enemies" % total
