extends Card



func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value
    if Global.dice_amount_rolled_this_turn == 1:
        base_damage = Global.roll_value * 3
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    Events.dice_rolled.connect(_on_dice_rolled)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. If you rolled only 1 Dice this turn, deal X3 instead"
    if not has_active_roll():
        return "Deal X damage. If you rolled only 1 Dice this turn, deal X3 instead"
    if Global.dice_amount_rolled_this_turn == 1:
        var tripled := apply_target_modifier(modifiers.get_modified_value(Global.roll_value * 3, Modifier.Type.DMG_DEALT), target)
        return "Deal %d damage (tripled - only 1 Dice rolled this turn)" % tripled
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage. If you rolled only 1 Dice this turn, deal X3 instead" % total
