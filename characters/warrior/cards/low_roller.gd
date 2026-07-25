extends Card

# Inverted scaling: the LESS Power you banked, the harder it hits. Gated on having
# actually rolled this turn (roll_history non-empty) - otherwise playing it cold off a
# fresh reset would be a free 12. An Evil crack (rolled 0) is the dream hit: history is
# non-empty, X is 0, full 12 lands.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty() or not has_active_roll():
        Events.reset_charged_card.emit()
        return
    var base := maxi(0, 12 - int(Global.roll_value))
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage"
    if not has_active_roll():
        return "Deal 12 - X damage"
    var base := maxi(0, 12 - int(Global.roll_value))
    var total := apply_target_modifier(modifiers.get_modified_value(base, Modifier.Type.DMG_DEALT), target)
    return "Deal 12 - X damage (%d)" % total
