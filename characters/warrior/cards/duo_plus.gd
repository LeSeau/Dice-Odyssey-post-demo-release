extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value == 2:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value * 6
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)

        Events.add_block.emit(Global.roll_value * 6)

        Events.dice_roll_reset.emit()
        Events.card_type_played.emit("exact")

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage and gain ? Block"
    if Global.roll_value == 2:
        var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value * 6, Modifier.Type.DMG_DEALT), target)
        var block := Global.roll_value * 6
        return "Deal X6 damage (%d) and gain X6 Block (%d)" % [total, block]
    return "Deal X6 damage and gain X6 Block"
