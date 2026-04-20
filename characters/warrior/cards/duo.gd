extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value  == 2:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = 7
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        
        Events.add_block.emit(7)
        Events.dice_rolled.connect(_on_dice_rolled)

        Events.dice_roll_reset.emit()
        Events.card_type_played.emit("exact")

func _on_dice_rolled():
    print("adding dice to damage")
