extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = 8
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        Events.dice_rolled.connect(_on_dice_rolled)
        damage_effect.sound = sound
        damage_effect.execute(targets)



func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var total := apply_target_modifier(modifiers.get_modified_value(8, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage" % total
