extends Card

# Dice Avalanche+ : identical to base (throw one Dice of each type you own, each deals its
# roll) but does NOT Exhaust. Own script only so the dynamic description drops "Exhaust".
# "Own" = permanent (max_amount) OR currently-held-temporarily (current_amount) - see
# dice_avalanche.gd for the full rationale (Julien, 2026-07-21 Occultism/Charge bug).


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var target: Node = targets[0]
    var tree := target.get_tree()
    var throws: Array = []
    for dice_type in DICE_FACE_VALUES:
        if int(Global.get("%s_dice_max_amount" % dice_type)) <= 0 \
                and int(Global.get("%s_dice_current_amount" % dice_type)) <= 0:
            continue
        var faces: Array = thrown_faces_for(dice_type)
        var value: int = faces[randi() % faces.size()]
        throws.append({"type": dice_type, "value": value, "target": target})
    # Same volley stagger as the flight visuals - see dice_avalanche.gd.
    var stagger := Global.dice_throw_volley_stagger(throws.size())
    for i in throws.size():
        var entry: Dictionary = throws[i]
        var value: int = entry["value"]
        var die_damage := modifiers.get_modified_value(value, Modifier.Type.DMG_DEALT)
        _land_thrown_die(tree, target, die_damage, Global.DICE_THROW_FLIGHT_TIME + stagger * i, sound, entry["type"], value)
    Events.dice_thrown.emit(throws, Global.last_played_card_position)
    Events.reset_charged_card.emit()


func _owned_type_count() -> int:
    var count := 0
    for dice_type in DICE_FACE_VALUES:
        if int(Global.get("%s_dice_max_amount" % dice_type)) > 0 \
                or int(Global.get("%s_dice_current_amount" % dice_type)) > 0:
            count += 1
    return count


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    return "Throw one Dice of each type you own. Each deals its roll\n(%d Dice)" % _owned_type_count()
