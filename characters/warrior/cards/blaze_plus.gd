extends Card

const WEAK_STATUS = preload("res://statuses/weak.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    Global.roll_value+=9
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    var status_effect := StatusEffect.new()
    var weak := WEAK_STATUS.duplicate()
    weak.stacks = 1
    status_effect.status = weak
    status_effect.execute(targets)
    support_effect.sound = sound
    support_effect.execute(targets)

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this adds a flat 9 Power,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
func plays_at_zero_power() -> bool:
    return true
