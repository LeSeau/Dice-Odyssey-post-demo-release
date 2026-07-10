extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var base := Global.roll_value
    var final_damage := base * 5 if _has_triple() else base
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(final_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _has_triple() -> bool:
    var counts: Dictionary = {}
    for v in Global.roll_history:
        counts[v] = counts.get(v, 0) + 1
        if counts[v] >= 3:
            return true
    return false

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. If you have three identical rolls in your current power, deal ?x5 damage instead"
    if not has_active_roll():
        return "Deal X damage. If you have three identical rolls in your current power, deal X5 damage instead"
    var base := Global.roll_value
    if _has_triple():
        var total := apply_target_modifier(modifiers.get_modified_value(base * 5, Modifier.Type.DMG_DEALT), target)
        return "JACKPOT! Deal %d damage" % total
    var total := apply_target_modifier(modifiers.get_modified_value(base, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage (no triple yet in your current power)" % total
