extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value + Global.roll_history.size() * 3
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal ? damage + 3 for each consecutive Dice roll"
    if not has_active_roll():
        return "Deal X damage + 3 for each consecutive Dice roll"
    var base := Global.roll_value
    var stacks := Global.roll_history.size()
    var total := modifiers.get_modified_value(base + stacks * 3, Modifier.Type.DMG_DEALT)
    return "Deal %d damage (%d + 3 per consecutive dice rolled)" % [total, base]
