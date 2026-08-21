extends Card

# Three payoffs on one card, all keyed off the same bank. Written in X notation on purpose
# (Julien, 2026-08-20) even though the Exact 7 gate pins X to 7 - the glyph teaches that this
# scales with Power, and the resolved number rides along in parentheses.
#
# Only the damage clause is resolved in the preview: Block and Gold are X exactly, with no
# modifier in front of them, so a second and third parenthesis would restate the same number.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if not meets_requirement():
        return
    var power := Global.roll_value
    if not targets.is_empty():
        var damage_effect := DamageEffect.new()
        damage_effect.amount = modifiers.get_modified_value(power * 2, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
    Events.add_block.emit(power)
    Global.gold += power
    Events.gold_changed.emit()
    Events.dice_roll_reset.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var base := "Deal X2 damage, gain X Block and X Gold. Exhaust"
    if is_inked():
        return "Deal ? damage, gain ? Block and ? Gold. Exhaust"
    if not has_active_roll() or not meets_requirement():
        return base
    var total := apply_target_modifier(
        modifiers.get_modified_value(Global.roll_value * 2, Modifier.Type.DMG_DEALT), target)
    return "Deal X2 damage (%d), gain X Block and X Gold. Exhaust" % total
