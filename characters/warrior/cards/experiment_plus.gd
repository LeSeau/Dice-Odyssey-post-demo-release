extends Card

# Upgraded Experiment: same X damage as the base card (the old "+3" is gone -
# the upgrade is now the second Charge), then Charge 2 random Dice. The two
# picks are independent, so the same type can come up twice (same as
# WarRitualStatus). See experiment.gd for the shared conventions.

const CHARGE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]
const CHARGE_COUNT := 2


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
        # One typed emit per die - each delivery flies in its own type's color (the reveal).
        Events.dice_charged.emit(chosen, 1)
    Events.dice_amount_changed.emit()

    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Charge 2 random Dice"
    if not has_active_roll():
        return "Deal X damage. Charge 2 random Dice"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d). Charge 2 random Dice" % total
