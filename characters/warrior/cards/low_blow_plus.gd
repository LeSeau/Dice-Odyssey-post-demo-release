extends Card

var base_damage = 0


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value < 4:
        base_damage = Global.roll_value*4
        var damage_effect := DamageEffect.new()
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
        return "Deal X4 damage"
    var total := modifiers.get_modified_value(Global.roll_value * 4, Modifier.Type.DMG_DEALT)
    return "Deal %d damage" % total
