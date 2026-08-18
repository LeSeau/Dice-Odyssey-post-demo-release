extends Card

# "When a card resets your Power, keep 5." Every turn gets a head start, and Refinement can
# round the leftover straight up to 7. Applied in dice.gd::_on_dice_roll_reset, which only
# honours it when there was MORE than the floor to begin with - it can never ADD Power.

const KEPT := 5


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.power_kept_on_reset = maxi(Global.power_kept_on_reset, KEPT)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    status_effect.status = preload("res://statuses/status_reservoir.tres").duplicate()
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
