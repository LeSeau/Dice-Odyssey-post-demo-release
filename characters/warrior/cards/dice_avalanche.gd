extends Card

# Celestial rare: conjures one die of every type you OWN and hurls them all at the target,
# each dealing its own roll - your real pool is untouched, unlike All In. "Own" means either
# a permanent type (max_amount > 0, from the shop) OR a type you currently have at least one
# of temporarily (current_amount > 0, from Charge/Occultism/relics/etc.) - checking max_amount
# alone missed a Giant Dice granted purely via Charge on a run that never bought one (Julien,
# 2026-07-21: Occultism into Dice Avalanche skipped the Giant Dice it had just charged).
# SUPPORT flag: never resets your Power. Exhausts.


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
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
    # Damage timers use the SAME volley stagger as the flight visuals (the shared helper
    # needs the final count, hence the second pass) - each hit lands exactly on its die's
    # slam, sequenced "bam bam bam" instead of the old stacked mush.
    var stagger := Global.dice_throw_volley_stagger(throws.size())
    for i in throws.size():
        var entry: Dictionary = throws[i]
        var value: int = entry["value"]
        # Thrown dice deal their RAW face value: no Strength, no player DMG_DEALT modifier
        # (Julien, 2026-08-20 - a 9-die Avalanche multiplied Strength nine times). Trebuchet's
        # Global.thrown_dice_bonus_fight, applied in card.gd::_on_thrown_die_landed, is now the
        # ONLY way to scale a thrown die. The target's own Exposed still applies on the target.
        var die_damage: int = value
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
    return "Throw one Dice of each type you own. Each deals damage equal to its roll. Exhaust\n(%d Dice)" % _owned_type_count()
