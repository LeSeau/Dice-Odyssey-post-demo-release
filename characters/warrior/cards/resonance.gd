extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var total := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    var damage_effect := DamageEffect.new()
    damage_effect.amount = total
    damage_effect.sound = sound
    damage_effect.execute(targets)
    # Pair check on the current bank: if any value shows up twice among this
    # turn's rolls (not just the last two), the hit lands a second time.
    if _has_pair():
        var damage_effect_2 := DamageEffect.new()
        damage_effect_2.amount = total
        damage_effect_2.sound = sound
        damage_effect_2.execute(targets)
    Events.dice_roll_reset.emit()

func _has_pair() -> bool:
    var seen: Dictionary = {}
    for v in Global.roll_history:
        if seen.has(v):
            return true
        seen[v] = true
    return false

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. If you have two identical rolls in your current power, deal ? damage again"
    if not has_active_roll():
        return "Deal X damage. If you have two identical rolls in your current power, deal X damage again"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    if _has_pair():
        return "Deal %d damage, then %d damage again (pair found)" % [total, total]
    return "Deal %d damage (no pair yet in your current power)" % total
