extends Card

# Upgraded Corrode: same Exact 7 gate, deeper rot (Exposed 3 instead of 2). See corrode.gd for
# why the gate is 7.

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")

const EXPOSED_DURATION := 3


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if meets_requirement():
        var damage_effect := DamageEffect.new()
        damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        var status_effect := StatusEffect.new()
        var exposed: Status = EXPOSED_STATUS.duplicate()
        exposed.duration = EXPOSED_DURATION
        status_effect.status = exposed
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()


func get_dynamic_description(modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage and apply Exposed 3 to ALL enemies"
    if not has_active_roll() or not meets_requirement():
        return "Deal X damage and apply Exposed 3 to ALL enemies"
    var total := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    return "Deal X damage and apply Exposed 3 to ALL enemies (%d)" % total
