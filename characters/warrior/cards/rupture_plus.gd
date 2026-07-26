extends Card

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const WEAK_STATUS = preload("res://statuses/weak.tres")

var base_damage := 4
var exposed_duration := 3
var weak_duration := 2

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6:
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()
        #
        var status_effect := StatusEffect.new()
        var exposed := EXPOSED_STATUS.duplicate()
        exposed.duration = exposed_duration
        status_effect.status = exposed
        status_effect.execute(targets)
    Events.reset_charged_card.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Apply Exposed 3"
    if not has_active_roll() or not meets_requirement():
        return "Deal X damage. Apply Exposed 3"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage. Apply Exposed 3" % total
