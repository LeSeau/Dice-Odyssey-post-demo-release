extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value < 4:
        return
    Events.reset_charged_card.emit()
    # Strip block BEFORE the hit so the full X lands - the whole identity of the
    # card. Direct stats write, same as enemy block resets elsewhere (the setter
    # clamps and emits stats_changed for the UI).
    for target in targets:
        if target.get("stats") != null:
            target.stats.block = 0
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Remove the target's Block, then deal ? damage"
    if not has_active_roll() or not meets_requirement():
        return "Remove the target's Block, then deal X damage"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Remove the target's Block, then deal X damage (%d)" % total
