extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    # Kill check right after the (synchronous) damage: enemy death defers the
    # node's removal, so stats are still readable this frame. A kill keeps the
    # bank alive (same valve as Eclipse/Resonance) - chain executions.
    if not targets.is_empty() and is_instance_valid(targets[0]) \
            and targets[0].get("stats") != null and targets[0].stats.health <= 0:
        Global.no_reset = true
    Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. If this kills the target, your Power is not reset"
    if not has_active_roll():
        return "Deal X damage. If this kills the target, your Power is not reset"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d). If this kills the target, your Power is not reset" % total
