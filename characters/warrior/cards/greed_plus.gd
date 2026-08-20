extends Card

# Base Greed with a bigger cut of the same bank: X3 damage and X2 Block, Gold unchanged.
# See greed.gd for why this is written in X notation despite the Exact gate.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if not meets_requirement():
        return
    var power := Global.roll_value
    if not targets.is_empty():
        var damage_effect := DamageEffect.new()
        damage_effect.amount = modifiers.get_modified_value(power * 3, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
    Events.add_block.emit(power * 2)
    Global.gold += power
    Events.gold_changed.emit()
    Events.dice_roll_reset.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var base := "Deal X3 damage, gain X2 Block and X Gold. Exhaust"
    if is_inked():
        return "Deal ? damage, gain ? Block and ? Gold. Exhaust"
    if not has_active_roll() or not meets_requirement():
        return base
    var total := apply_target_modifier(
        modifiers.get_modified_value(Global.roll_value * 3, Modifier.Type.DMG_DEALT), target)
    return "Deal X3 damage (%d), gain X2 Block and X Gold. Exhaust" % total
