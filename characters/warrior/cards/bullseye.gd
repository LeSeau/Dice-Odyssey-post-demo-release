extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value % 6 == 0:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = floor(Global.roll_value*3)
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        Events.dice_rolled.connect(_on_dice_rolled)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()
    

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal ? damage"
    if not has_active_roll() or not meets_requirement():
        return "Deal X3 damage"
    var total := modifiers.get_modified_value(floor(Global.roll_value * 3), Modifier.Type.DMG_DEALT)
    return "Deal %d damage" % total
