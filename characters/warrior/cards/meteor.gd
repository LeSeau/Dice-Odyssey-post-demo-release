extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    # Base Meteor is gated Min 5 (Julien, 2026-07-21); Meteor+ reuses this same script with
    # requirement NONE, so meets_requirement() there always passes. No-op below Min 5.
    if targets.is_empty() or not meets_requirement():
        Events.reset_charged_card.emit()
        return
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    # The meteor: a conjured Giant Dice (not from your pool) rolled at throw time - the
    # visual cycles faces mid-flight and lands on this value, the damage lands with it.
    var faces: Array = thrown_faces_for("giant")
    var value: int = faces[randi() % faces.size()]
    var target: Node = targets[0]
    Events.dice_thrown.emit([{"type": "giant", "value": value, "target": target}], Global.last_played_card_position)
    var die_damage := modifiers.get_modified_value(value, Modifier.Type.DMG_DEALT)
    _land_thrown_die(target.get_tree(), target, die_damage, Global.DICE_THROW_FLIGHT_TIME, sound, "giant", value)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Throw a Giant Dice that deals damage equal to its roll"
    if not has_active_roll() or not meets_requirement():
        return "Deal X damage. Throw a Giant Dice that deals damage equal to its roll"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage. Throw a Giant Dice that deals damage equal to its roll" % total
