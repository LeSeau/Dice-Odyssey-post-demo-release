extends Card

# Base Smash plus the Exposed rider it used to carry. Exposed is a flat +50% damage taken for
# N turns - the number is DURATION, not magnitude - so 2 means "the rest of this turn and the
# next one" on every body it hits.

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const EXPOSED_DURATION := 2


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if not meets_requirement():
        return
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value * 2, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    var status_effect := StatusEffect.new()
    var exposed: Status = EXPOSED_STATUS.duplicate()
    exposed.duration = EXPOSED_DURATION
    status_effect.status = exposed
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage to ALL enemies. Apply Exposed 2"
    if not has_active_roll() or not meets_requirement():
        return "Deal X2 damage to ALL enemies. Apply Exposed 2"
    var total := apply_target_modifier(
        modifiers.get_modified_value(Global.roll_value * 2, Modifier.Type.DMG_DEALT), target)
    return "Deal X2 damage (%d) to ALL enemies. Apply Exposed 2" % total
