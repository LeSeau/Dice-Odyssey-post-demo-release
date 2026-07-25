extends Card

# Double or Nothing+ : X3 on heads instead of X2 (base double_or_nothing.gd). Same coin flip;
# tails still refunds your Power.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var heads := randi() % 2 == 0
    var damage := modifiers.get_modified_value(Global.roll_value * 3, Modifier.Type.DMG_DEALT)
    var target: Node = targets[0]
    var tree := target.get_tree()
    Events.coin_flip.emit(heads, Global.last_played_card_position, target)
    var timer := tree.create_timer(Global.COIN_FLIP_TIME, false)
    timer.timeout.connect(_on_coin_resolved.bind(tree, target, heads, damage))
    Events.reset_charged_card.emit()


func _on_coin_resolved(tree: SceneTree, target: Node, heads: bool, damage: int) -> void:
    if not heads:
        return
    var final_target := target
    if final_target == null or not is_instance_valid(final_target):
        var alive := tree.get_nodes_in_group("enemies")
        if alive.is_empty():
            return
        final_target = alive[randi() % alive.size()]
    var damage_effect := DamageEffect.new()
    damage_effect.amount = damage
    damage_effect.sound = sound
    damage_effect.execute([final_target])
    Events.dice_roll_reset.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Flip a coin: deal ? damage, or keep your Power"
    if not has_active_roll():
        return "Flip a coin: deal X3 damage, or keep your Power"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value * 3, Modifier.Type.DMG_DEALT), target)
    return "Flip a coin: deal %d damage, or keep your Power" % total
