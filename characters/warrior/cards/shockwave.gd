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

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Does not reset your Power"
    if not has_active_roll() or not meets_requirement():
        return "Deal X damage. Does not reset your Power"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d). Does not reset your Power" % total
