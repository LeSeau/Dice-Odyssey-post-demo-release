extends Card

# Celestial rare: conjures one die of every type you OWN (max_amount > 0 - your pool is
# untouched, unlike All In) and hurls them all at the target, each dealing its own roll.
# SUPPORT flag: never resets your Power. Exhausts.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var target: Node = targets[0]
    var tree := target.get_tree()
    var throws: Array = []
    var i := 0
    for dice_type in DICE_FACE_VALUES:
        if int(Global.get("%s_dice_max_amount" % dice_type)) <= 0:
            continue
        var faces: Array = DICE_FACE_VALUES[dice_type]
        var value: int = faces[randi() % faces.size()]
        throws.append({"type": dice_type, "value": value, "target": target})
        # Strength applies per die (Julien, 2026-07-21) - up to 9 dice, so this is the
        # single biggest Strength multiplier of any card in the pool. Watch in playtest.
        var die_damage := modifiers.get_modified_value(value, Modifier.Type.DMG_DEALT)
        _land_thrown_die(tree, target, die_damage, Global.DICE_THROW_FLIGHT_TIME + Global.DICE_THROW_STAGGER * i, sound)
        i += 1
    Events.dice_thrown.emit(throws, Global.last_played_card_position)
    Events.reset_charged_card.emit()


func _owned_type_count() -> int:
    var count := 0
    for dice_type in DICE_FACE_VALUES:
        if int(Global.get("%s_dice_max_amount" % dice_type)) > 0:
            count += 1
    return count


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    return "Throw one Dice of each type you own. Each deals its roll. Exhaust\n(%d Dice)" % _owned_type_count()
