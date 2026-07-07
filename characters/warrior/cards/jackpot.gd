extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage := 30 if _has_triple() else 6
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _has_triple() -> bool:
    var h: Array = Global.roll_history
    if h.size() < 3:
        return false
    return h[h.size() - 1] == h[h.size() - 2] and h[h.size() - 2] == h[h.size() - 3]

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if has_active_roll() and _has_triple():
        var total := modifiers.get_modified_value(30, Modifier.Type.DMG_DEALT)
        return "JACKPOT! Deal %d damage" % total
    return "Deal 6 damage. If your last three rolls all match, deal 30 instead"
