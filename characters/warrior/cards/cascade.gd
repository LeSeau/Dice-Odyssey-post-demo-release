extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    # Straight check over the whole current chain (values in any order): the card
    # no-ops without one, standard unmet-requirement behavior for this game.
    if not _has_run():
        return
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(_chain_total(), Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _chain_total() -> int:
    var total := 0
    for v in Global.roll_history:
        total += int(v)
    return total

func _has_run() -> bool:
    var values := {}
    for v in Global.roll_history:
        values[int(v)] = true
    for v in values.keys():
        if values.has(v + 1) and values.has(v + 2):
            return true
    return false

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal the total of your chain as damage to ALL enemies. Only works if your chain holds 3 consecutive values"
    if not has_active_roll() or not _has_run():
        return "Deal the total of your chain as damage to ALL enemies. Only works if your chain holds 3 consecutive values"
    var total := modifiers.get_modified_value(_chain_total(), Modifier.Type.DMG_DEALT)
    return "STRAIGHT! Deal %d damage to ALL enemies (the total of your chain)" % total
