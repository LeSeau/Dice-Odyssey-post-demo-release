extends Card

# Deal X - and if you rolled 5+ dice this turn (the dice-volume archetype: refuels,
# charges, big pools), it hits a second time ~a quarter second later for the double-hit
# feel. Damage locked at play time; if the target dies to the first hit, the second one
# tramples into a random living enemy.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var damage := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    var first_hit := DamageEffect.new()
    first_hit.amount = damage
    first_hit.sound = sound
    first_hit.execute(targets)
    if Global.dice_amount_rolled_this_turn >= 5:
        var target: Node = targets[0]
        var tree := target.get_tree()
        var timer := tree.create_timer(0.25, false)
        timer.timeout.connect(_on_second_hit.bind(tree, target, damage))
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func _on_second_hit(tree: SceneTree, target: Node, damage: int) -> void:
    var final_target := target
    if final_target == null or not is_instance_valid(final_target):
        var alive := tree.get_nodes_in_group("enemies")
        if alive.is_empty():
            return
        final_target = alive[randi() % alive.size()]
    var second_hit := DamageEffect.new()
    second_hit.amount = damage
    second_hit.sound = sound
    second_hit.execute([final_target])


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var suffix := " (%d rolled)" % Global.dice_amount_rolled_this_turn
    if is_inked():
        return "Deal ? damage. If you rolled 5+ Dice this turn, deal it twice" + suffix
    if not has_active_roll():
        return "Deal X damage. If you rolled 5+ Dice this turn, deal it twice" + suffix
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return ("Deal %d damage. If you rolled 5+ Dice this turn, deal it twice" % total) + suffix
