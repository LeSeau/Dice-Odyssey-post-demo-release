extends Card

# Meteor+ throws a HEAVIER stone: the Giant die it conjures rolls 7-12 instead of 1-12, the
# same face set the Bulky infusion grants (Julien, 2026-08-20). Written as an explicit range
# rather than by calling thrown_faces_for("giant") so the upgrade is a real upgrade even for
# a player who already owns Bulky - otherwise the two would collapse into the same card.
#
# Keeps the base card's Min 5 gate. Its own X damage still takes Strength; the thrown die
# does not (2026-08-20 rule change) - Trebuchet is the only thing that scales a throw now.

const HEAVY_FACES: Array = [7, 8, 9, 10, 11, 12]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty() or not meets_requirement():
        Events.reset_charged_card.emit()
        return
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    var value: int = HEAVY_FACES[randi() % HEAVY_FACES.size()]
    var target: Node = targets[0]
    Events.dice_thrown.emit([{"type": "giant", "value": value, "target": target}],
            Global.last_played_card_position)
    _land_thrown_die(target.get_tree(), target, value, Global.DICE_THROW_FLIGHT_TIME, sound,
            "giant", value)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var base := "Deal X damage. Throw a Giant Dice that rolls 7-12 and deals damage equal to its roll"
    if is_inked():
        return "Deal ? damage. Throw a Giant Dice that rolls 7-12 and deals damage equal to its roll"
    if not has_active_roll() or not meets_requirement():
        return base
    var total := apply_target_modifier(
        modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d). Throw a Giant Dice that rolls 7-12 and deals damage equal to its roll" % total
