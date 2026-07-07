extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    # Pair check on the current chain: if the two most recent rolls match, the
    # bank survives this play (same suppression valve Eclipse uses - dice.gd
    # consumes Global.no_reset inside _on_dice_roll_reset and skips the reset).
    if _has_pair():
        Global.no_reset = true
    Events.dice_roll_reset.emit()

func _has_pair() -> bool:
    var h: Array = Global.roll_history
    return h.size() >= 2 and h[h.size() - 1] == h[h.size() - 2]

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal ? damage. If your last two rolls match, your Power is not reset"
    if not has_active_roll():
        return "Deal X damage. If your last two rolls match, your Power is not reset"
    var total := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    if _has_pair():
        return "Deal %d damage. Your last two rolls match: your Power will NOT reset" % total
    return "Deal %d damage (last two rolls do not match: your Power will reset)" % total
