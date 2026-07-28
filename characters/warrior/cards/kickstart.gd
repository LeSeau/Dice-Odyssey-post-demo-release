extends Card

# Cash a DELIBERATELY small roll in for permanent muscle (Julien, 2026-07-25): gated Max 3
# (Max 5 on Kickstart+, which reuses this script - meets_requirement() reads the card's own
# number), it converts your whole Power into that many Strength for the rest of the fight,
# then resets. The Low Roll archetype's long game: a 1 you'd normally curse becomes a
# permanent +1 on every hit. No longer a Throw card - the die is gone, the Power IS the
# input now.

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    # has_active_roll() (not roll_value > 0) so an Evil crack still counts as a real roll -
    # it just converts to nothing. Playing off a fresh reset does nothing and costs nothing.
    if targets.is_empty() or not has_active_roll() or not meets_requirement():
        Events.reset_charged_card.emit()
        return
    var gain := int(Global.roll_value)
    if gain > 0:
        var status_effect := StatusEffect.new()
        var muscle: Status = MUSCLE_STATUS.duplicate()
        muscle.stacks = gain
        status_effect.status = muscle
        status_effect.sound = sound
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Gain ? Strength. Exhaust"
    if not has_active_roll() or not meets_requirement():
        return "Gain X Strength. Exhaust"
    return "Gain %d Strength. Exhaust" % int(Global.roll_value)
