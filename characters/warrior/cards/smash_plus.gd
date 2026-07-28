extends Card

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if meets_requirement():
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value * 2
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)

        var status_effect := StatusEffect.new()
        var exposed := EXPOSED_STATUS.duplicate()
        exposed.duration = 2
        status_effect.status = exposed
        status_effect.execute(targets)

        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Apply Exposed 2"
    if not has_active_roll() or not meets_requirement():
        return "Deal X2 damage. Apply Exposed 2"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value * 2, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage. Apply Exposed 2" % total
