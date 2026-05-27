extends Card



func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value == 1:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = 8
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        Events.dice_rolled.connect(_on_dice_rolled)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()  
    

func _on_dice_rolled():
    print("adding dice to damage")
