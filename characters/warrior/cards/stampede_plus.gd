extends Card

# Stampede+ : if you rolled 5+ Dice this turn, deal X THREE times (base deals it twice).
# Same gate, one extra trample. Second/third hits retarget to a living enemy if the first
# kills. See stampede.gd.


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
        tree.create_timer(0.25, false).timeout.connect(_on_extra_hit.bind(tree, target, damage))
        tree.create_timer(0.50, false).timeout.connect(_on_extra_hit.bind(tree, target, damage))
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func _on_extra_hit(tree: SceneTree, target: Node, damage: int) -> void:
    var final_target := target
    if final_target == null or not is_instance_valid(final_target):
        var alive := tree.get_nodes_in_group("enemies")
        if alive.is_empty():
            return
        final_target = alive[randi() % alive.size()]
    var hit := DamageEffect.new()
    hit.amount = damage
    hit.sound = sound
    hit.execute([final_target])


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var suffix := " (%d rolled)" % Global.dice_amount_rolled_this_turn
    if is_inked():
        return "Deal ? damage. If you rolled 5+ Dice this turn, deal it three times" + suffix
    if not has_active_roll():
        return "Deal X damage. If you rolled 5+ Dice this turn, deal it three times" + suffix
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return ("Deal %d damage. If you rolled 5+ Dice this turn, deal it three times" % total) + suffix
