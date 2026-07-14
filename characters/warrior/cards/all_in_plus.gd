extends Card

const ALL_DICE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]

# Real face-value pools per type - each remaining die is rolled from ITS OWN range and that
# same value both drives the damage bonus AND picks the face texture shown in the flourish
# (dice.gd::_spawn_all_in_consumed).
const DISPLAY_FACE_VALUES := {
    "blue": [1, 2, 3, 4, 5, 6], "red": [1, 2, 3, 4, 5, 6],
    "magma": [1, 2, 3, 4, 5, 6], "mech": [1, 2, 3, 4, 5, 6],
    "giant": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    "evil": [0, 6, 6, 6],
    "even": [2, 4, 6, 8],
    "odd": [1, 3, 5, 7],
    "green": [1, 2, 3],
}

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    # Charge 1 Blue Dice FIRST - it gets swept into the "spend everything" pass
    # below along with every other remaining die, so it contributes its own
    # roll to the bonus instead of surviving as a free die for next turn.
    Global.blue_dice_current_amount += 1
    Events.dice_amount_changed.emit()
    Events.charge_dice_animation.emit()
    Events.temporary_dice_added.emit("blue")
    # By the time this card resolves, the die that carried it is already spent -
    # "remaining" is every other die left in every pool, not just Red anymore.
    var bonus := 0
    var consumed: Array[Dictionary] = []
    for dice_type in ALL_DICE_TYPES:
        var prop := "%s_dice_current_amount" % dice_type
        var remaining: int = Global.get(prop)
        var display_faces: Array = DISPLAY_FACE_VALUES.get(dice_type, [1, 2, 3, 4, 5, 6])
        for i in remaining:
            var rolled_value: int = display_faces[randi() % display_faces.size()]
            bonus += rolled_value
            consumed.append({"type": dice_type, "value": rolled_value})
        Global.set(prop, 0)
    # Fires before the damage lands, so the "your dice got consumed for this" flourish is
    # already rising by the time the hit/number appears. Anchored on the targeted enemy.
    var flourish_position := Global.last_played_card_position
    if not targets.is_empty() and is_instance_valid(targets[0]):
        var primary_target: Node = targets[0]
        if primary_target is Enemy:
            flourish_position = primary_target.intent_ui.global_position + primary_target.intent_ui.size / 2.0
        elif primary_target is Node2D:
            flourish_position = primary_target.global_position
    Events.all_in_dice_consumed.emit(consumed, flourish_position)
    var damage_effect := DamageEffect.new()
    var base_damage: int = Global.roll_value + bonus
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_amount_changed.emit()
    Events.dice_roll_reset.emit()

func _total_remaining() -> int:
    var total := 0
    for dice_type in ALL_DICE_TYPES:
        total += int(Global.get("%s_dice_current_amount" % dice_type))
    return total

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    return "Charge 1 Blue Dice. Then, deal X damage: spend all your remaining Dice, each adds its own roll\n(%d Dice remaining)" % _total_remaining()
