extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = 6
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var total := apply_target_modifier(modifiers.get_modified_value(6, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage" % total
