extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value  == 2:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value * 4
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)

        Events.add_block.emit(Global.roll_value * 4)
        Events.dice_rolled.connect(_on_dice_rolled)

        Events.dice_roll_reset.emit()
        Events.card_type_played.emit("exact")

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage and gain ? block"
    if Global.roll_value == 2:
        var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value * 4, Modifier.Type.DMG_DEALT), target)
        var block := Global.roll_value * 4
        return "Deal %d damage and gain %d block" % [total, block]
    return "Deal X4 damage and gain X4 block"
