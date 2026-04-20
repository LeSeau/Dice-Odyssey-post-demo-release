extends Card



func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value
    if Global.fight_dice_rolled == 1:
        base_damage = Global.roll_value * 3
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    Events.dice_rolled.connect(_on_dice_rolled)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
        
func _on_dice_rolled():
    

    print("adding dice to damage")
