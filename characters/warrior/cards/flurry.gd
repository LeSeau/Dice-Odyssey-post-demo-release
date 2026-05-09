extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    damage_effect.sound = sound  
    var base_damage = Global.roll_value * 2
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
