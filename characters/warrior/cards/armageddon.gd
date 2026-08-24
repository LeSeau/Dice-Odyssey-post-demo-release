extends Card

# "You may roll the Red Dice with an empty socket. It deals X damage to ALL enemies."
# Turns Red from a pure gamble-enabler into an artillery die worth stacking - and it is the
# Red ladder's missing ENABLER in spirit: a reason to own Red dice for their own sake.
# The roll behaviour lives in dice.gd (the roll gate + _fire_socketless_red); this card only
# raises the flag, which battle.gd clears at the start of each fight.

const BLESSING_STATUS = preload("res://statuses/status_socketless_red.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.socketless_red = true
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    status_effect.status = BLESSING_STATUS.duplicate()
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
