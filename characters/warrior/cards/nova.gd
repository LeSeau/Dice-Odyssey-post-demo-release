extends Card

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)

    if Global.roll_history.size() >= 2 and not targets.is_empty():
        var enemies = targets[0].get_tree().get_nodes_in_group("enemies")
        var damage_effect := DamageEffect.new()
        damage_effect.amount = 5
        damage_effect.sound = sound
        damage_effect.execute(enemies)

    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Block ?. If you rolled more than 1 Dice, deal 5 damage to all enemies"
    if not has_active_roll():
        return "Block X. If you rolled more than 1 Dice, deal 5 damage to all enemies"
    return "Block %d. If you rolled more than 1 Dice, deal 5 damage to all enemies" % Global.roll_value
