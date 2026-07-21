extends Card

# Celestial side-channel damage: spends one die from your ACTIVE pool instead of using
# Power at all (SUPPORT rarity flag = playing this never resets your bank). With 0 active
# dice remaining it whiffs - still discards, like any failed-requirement play.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var prop := "%s_dice_current_amount" % Global.dice_type
    if int(Global.get(prop)) <= 0:
        Events.reset_charged_card.emit()
        return
    Global.set(prop, int(Global.get(prop)) - 1)
    Events.dice_amount_changed.emit()
    var faces: Array = DICE_FACE_VALUES.get(Global.dice_type, [1, 2, 3, 4, 5, 6])
    var value: int = faces[randi() % faces.size()]
    var target: Node = targets[0]
    Events.dice_thrown.emit([{"type": Global.dice_type, "value": value, "target": target}], Global.last_played_card_position)
    # Strength applies to thrown-die damage (Julien, 2026-07-21), consistent with the other
    # throw cards - the die is a real hit, not raw.
    var die_damage := modifiers.get_modified_value(value * 2, Modifier.Type.DMG_DEALT)
    _land_thrown_die(target.get_tree(), target, die_damage, Global.DICE_THROW_FLIGHT_TIME, sound)
    Events.reset_charged_card.emit()


func _active_remaining() -> int:
    return int(Global.get("%s_dice_current_amount" % Global.dice_type))


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if _active_remaining() <= 0:
        return "Spend 1 of your active Dice: it deals double its roll\n(no Dice left!)"
    return "Spend 1 of your active Dice: it deals double its roll"
