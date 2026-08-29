extends Card

# Reworked 2026-08-16 (Julien): was "Deal X damage. Apply Exposed 2", which was too close to
# Smash. Now it inverts the game's sequencing - every other card wants to be played AFTER you
# have banked, this one wants to be played at 0 Power and then rolled INTO.
#
# The per-roll bleed lives in RupturedStatus (statuses/ruptured.gd) because it has to survive
# this card leaving play and listen to three separate roll signals.

const RUPTURED_STATUS = preload("res://statuses/ruptured.tres")


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
