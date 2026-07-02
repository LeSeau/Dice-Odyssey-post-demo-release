extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = 6
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        Events.dice_rolled.connect(_on_dice_rolled)
        damage_effect.sound = sound
        damage_effect.execute(targets)

    

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    var total := modifiers.get_modified_value(6, Modifier.Type.DMG_DEALT)
    return "Deal %d damage" % total
