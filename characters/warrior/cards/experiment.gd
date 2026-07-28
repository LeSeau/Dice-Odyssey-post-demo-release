extends Card

# Deal X damage, then Charge 1 random Dice. A type you don't own is still a valid
# pick - the charge hands you a temporary die of that type for the turn.
# RULE (Julien, 2026-07-28): a "random Dice" pool is ALWAYS all 9 types, "evil"
# included - no exceptions. Six sites used to omit it (deviation, sharpening(+),
# war_ritual, dicelord_gift, arcane_hat, dice_chip) purely from copy-paste drift,
# never by design; they were all swept the same day. Copy from any of them.
# CHARGE_COUNT is the only difference from experiment_plus.gd.

const CHARGE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]
const CHARGE_COUNT := 1


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)

    for i in CHARGE_COUNT:
        var chosen: String = CHARGE_TYPES[randi() % CHARGE_TYPES.size()]
        var prop := chosen + "_dice_current_amount"
        Global.set(prop, int(Global.get(prop)) + 1)
        Events.temporary_dice_added.emit(chosen)
    Events.charge_dice_animation.emit()
    Events.dice_amount_changed.emit()

    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Charge a random Dice"
    if not has_active_roll():
        return "Deal X damage. Charge a random Dice"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage. Charge a random Dice" % total
