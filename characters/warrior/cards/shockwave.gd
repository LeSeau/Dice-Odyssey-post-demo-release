extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    if Global.roll_value <= 10:
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
    Events.reset_charged_card.emit()
        #return
    #Events.dice_roll_reset.emit()
