extends Card

# Rupture+ mirrors the reworked base card (2026-08-16) instead of the pre-rework
# "Deal X damage. Apply Exposed 2" it used to upgrade from - that stale version survived the
# rework and shipped, promising Exposed on a card that no longer applies it.
#
# The upgrade drops the Min 6 gate entirely and raises the bleed 3 -> 4 per roll. Damage per
# roll lives on ruptured_plus.tres::stacks, so this script never retypes the number.

const RUPTURED_STATUS = preload("res://statuses/ruptured_plus.tres")


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if targets.is_empty():
        Events.dice_roll_reset.emit()
        return
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    var status_effect := StatusEffect.new()
    var ruptured: Status = RUPTURED_STATUS.duplicate()
    ruptured.duration = 1
    status_effect.status = ruptured
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var per_roll: int = RUPTURED_STATUS.stacks
    var tail := ". The enemy takes %d damage each time you roll a Dice this turn" % per_roll
    if is_inked():
        return "Deal ? damage" + tail
    if not has_active_roll():
        return "Deal X damage" + tail
    var total := apply_target_modifier(
        modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal X damage (%d)%s" % [total, tail]
