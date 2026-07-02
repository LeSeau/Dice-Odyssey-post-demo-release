extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    
    if Global.has_rolled_6_this_turn:
        await targets[0].get_tree().create_timer(0.5).timeout
        var bonus_damage := DamageEffect.new()
        bonus_damage.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        bonus_damage.sound = sound
        bonus_damage.execute(targets)
    
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        if Global.has_rolled_6_this_turn:
            return "Deal ? damage. (You have rolled a 6 this turn — deal ? damage again)"
        return "Deal ? damage. (You haven't rolled a 6 this turn)"
    if not has_active_roll():
        if Global.has_rolled_6_this_turn:
            return "Deal X damage. (You have rolled a 6 this turn — deal X damage again)"
        return "Deal X damage. (You haven't rolled a 6 this turn)"
    var total := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    if Global.has_rolled_6_this_turn:
        return "Deal %d damage. (You have rolled a 6 this turn — deal %d damage again)" % [total, total]
    return "Deal %d damage. (You haven't rolled a 6 this turn)" % total
