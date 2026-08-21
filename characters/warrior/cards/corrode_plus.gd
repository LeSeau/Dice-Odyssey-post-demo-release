extends Card

# Setup AND payoff in one card. Order matters and is deliberate: Exposed lands FIRST, so the
# card's own AoE is the first thing to enjoy the +50% it just applied.

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const EXPOSED_DURATION := 5


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if not meets_requirement():
        return
    var status_effect := StatusEffect.new()
    var exposed: Status = EXPOSED_STATUS.duplicate()
    exposed.duration = EXPOSED_DURATION
    status_effect.status = exposed
    status_effect.execute(targets)
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var base := "Apply Exposed 5 to ALL enemies, then deal X damage to ALL enemies"
    if is_inked():
        return "Apply Exposed 5 to ALL enemies, then deal ? damage to ALL enemies"
    if not has_active_roll() or not meets_requirement():
        return base
    var total := apply_target_modifier(
        modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Apply Exposed 5 to ALL enemies, then deal X damage (%d) to ALL enemies" % total
