extends Card

const ALL_DICE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]

# Real face-value pools per type, used ONLY to pick which face texture each consumed die shows
# in the flourish (dice.gd::_spawn_all_in_consumed) - kept separate from the randi_range(1,6)
# roll below that computes the actual damage bonus, so this is purely visual and doesn't touch
# the card's existing balance (every die type has always contributed a flat 1-6 to the bonus
# here, regardless of its real face range - not something this pass changes).
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
    # By the time this card resolves, the die that carried it is already spent -
    # "remaining" is every other die left in every pool, not just Red anymore.
    var bonus := 0
    var consumed: Array[Dictionary] = []
    for dice_type in ALL_DICE_TYPES:
        var prop := "%s_dice_current_amount" % dice_type
        var remaining: int = Global.get(prop)
        var display_faces: Array = DISPLAY_FACE_VALUES.get(dice_type, [1, 2, 3, 4, 5, 6])
        for i in remaining:
            bonus += randi_range(1, 6)
            consumed.append({"type": dice_type, "value": display_faces[randi() % display_faces.size()]})
        Global.set(prop, 0)
    # Fires before the damage lands, so the "your dice got consumed for this" flourish is
    # already rising by the time the hit/number appears - previously the player only saw the
    # damage number with no visible cause.
    Events.all_in_dice_consumed.emit(consumed)
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
    return "Deal X damage. Spend all your remaining Dice: each adds its own roll\n(%d Dice remaining)" % _total_remaining()
