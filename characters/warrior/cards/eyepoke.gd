extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.draw_card.emit(2)
    var damage_effect := DamageEffect.new()
    var base_damage = floor(Global.roll_value)
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
