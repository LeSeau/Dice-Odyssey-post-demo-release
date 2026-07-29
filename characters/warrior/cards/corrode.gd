extends Card

# Exact 7 - the room's whole front line rots at once: full banked Power to every enemy, plus
# Exposed on all of them so the follow-up turn hits harder too.
#
# Why 7 specifically: it's the Odd die's top face (so a single lucky Odd roll arms it), and
# Refinement pushes Power to the next multiple of 7, which makes it a real setup line rather
# than a coincidence.

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")

const EXPOSED_DURATION := 2


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


# AoE, so there's no single aimed target whose own DMG_TAKEN could be previewed here - the
# number shown is the player-side value, same as the other all-enemy attacks.
func get_dynamic_description(modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage and apply Exposed 2 to ALL enemies"
    if not has_active_roll() or not meets_requirement():
        return "Deal X damage and apply Exposed 2 to ALL enemies"
    var total := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    return "Deal X damage and apply Exposed 2 to ALL enemies (%d)" % total
