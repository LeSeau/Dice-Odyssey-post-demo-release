extends Card

const STEADY_HAND_STATUS = preload("res://statuses/status_steady_hand.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6 or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        var steady_hand := STEADY_HAND_STATUS.duplicate()
        status_effect.status = steady_hand
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
