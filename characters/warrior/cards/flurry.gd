extends Card

# Red-die payoff: the same hit lands HIT_COUNT times, a fifth of a second apart, instead of one
# doubled lump. Identical total to the old "X2", but every impact gets its own damage popup, its
# own hit-stop and its own trip through the target's Exposed - it reads as a flurry instead of a
# single big number. Damage is locked at play time; if an early hit kills, the rest trample into
# a random living enemy (same rule as stampede.gd).

const HIT_COUNT := 2
const HIT_INTERVAL := 0.2


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if not targets.is_empty():
        var damage := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
        var first_hit := DamageEffect.new()
        first_hit.amount = damage
        first_hit.sound = sound
        first_hit.execute(targets)
        var target: Node = targets[0]
        var tree := target.get_tree()
        for i in range(1, HIT_COUNT):
            var timer := tree.create_timer(HIT_INTERVAL * i, false)
            timer.timeout.connect(_on_follow_up_hit.bind(tree, target, damage))
    Events.dice_roll_reset.emit()


func _on_follow_up_hit(tree: SceneTree, target: Node, damage: int) -> void:
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
    if is_inked():
        return "Deal ? damage twice"
    if not has_active_roll():
        return "Deal X damage twice"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage twice" % total
