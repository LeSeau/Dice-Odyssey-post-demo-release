extends Card

# "Max 6: deal 7 damage per consecutive Dice roll."
# The two conditions fight each other on purpose - you want MANY rolls but a TINY total - and
# the pool already sells the solvers: Pixie (three d3s land around 6), a deliberate Unlucky,
# Mech's -1. roll_history is the chain itself; it is cleared on every reset and on a type
# switch, so its size is exactly "consecutive rolls".

const DAMAGE_PER_ROLL := 7


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Events.reset_charged_card.emit()
    var damage := modifiers.get_modified_value(_damage(), Modifier.Type.DMG_DEALT)
    if damage > 0 and not targets.is_empty():
        var damage_effect := DamageEffect.new()
        damage_effect.amount = damage
        damage_effect.sound = sound
        damage_effect.execute(targets)
    Events.dice_roll_reset.emit()


func _damage() -> int:
    return Global.roll_history.size() * DAMAGE_PER_ROLL


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var base := "Deal %d damage per consecutive Dice roll" % DAMAGE_PER_ROLL
    if is_inked():
        return base
    if not has_active_roll() or not meets_requirement():
        return base
    var total := apply_target_modifier(
        modifiers.get_modified_value(_damage(), Modifier.Type.DMG_DEALT), target)
    return "%s (%d)" % [base, total]

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this scales off the number of rolls in the chain, and the 0 roll is one of them,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
# Shared by Cadence and Cadence+.
func plays_at_zero_power() -> bool:
    return true
