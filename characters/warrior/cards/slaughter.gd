extends Card



func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value > 14:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = 25
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()
        
