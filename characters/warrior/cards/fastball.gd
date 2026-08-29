extends Card

# Celestial side-channel damage: spends one die from your ACTIVE pool instead of using
# Power at all (SUPPORT rarity flag = playing this never resets your bank). With 0 active
# dice remaining it whiffs - still discards, like any failed-requirement play.


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var prop := "%s_dice_current_amount" % Global.dice_type
    if int(Global.get(prop)) <= 0:
        Events.reset_charged_card.emit()
        return
    Global.set(prop, int(Global.get(prop)) - 1)
    Events.dice_amount_changed.emit()
    var thrown_type: String = Global.dice_type
    var faces: Array = thrown_faces_for(thrown_type)
    var value: int = faces[randi() % faces.size()]
    var target: Node = targets[0]
    Events.dice_thrown.emit([{"type": thrown_type, "value": value, "target": target}], Global.last_played_card_position)
    # Thrown dice deal their RAW face value: no Strength, no player DMG_DEALT modifier
    # (Julien, 2026-08-20 - a 9-die Avalanche multiplied Strength nine times). Trebuchet's
    # Global.thrown_dice_bonus_fight, applied in card.gd::_on_thrown_die_landed, is now the
    # ONLY way to scale a thrown die. The target's own Exposed still applies on the target.
    var die_damage: int = value * 2
    _land_thrown_die(target.get_tree(), target, die_damage, Global.DICE_THROW_FLIGHT_TIME, sound, thrown_type, value)
    Events.reset_charged_card.emit()


func _active_remaining() -> int:
    return int(Global.get("%s_dice_current_amount" % Global.dice_type))


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if _active_remaining() <= 0:
        return "Spend 1 of your active Dice: it deals double its roll\n(no Dice left!)"
    return "Spend 1 of your active Dice: it deals double its roll"
