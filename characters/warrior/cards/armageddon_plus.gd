extends Card

# Socketless Red+: same blessing, but every empty-socket Red roll ALSO grants Strength
# (Julien, 2026-08-20) - so it compounds across the fight instead of paying out once. The
# grant itself lives in dice.gd::_fire_socketless_red(), the only place that knows a
# socketless roll actually happened; this card just arms the amount.

const BLESSING_STATUS = preload("res://statuses/status_socketless_red_plus.tres")
const STRENGTH_PER_ROLL := 1


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.socketless_red = true
    Global.socketless_red_strength = STRENGTH_PER_ROLL
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    status_effect.status = BLESSING_STATUS.duplicate()
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
