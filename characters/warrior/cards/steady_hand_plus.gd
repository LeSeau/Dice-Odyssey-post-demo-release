extends Card

const STEADY_HAND_PLUS_STATUS = preload("res://statuses/status_steady_hand_plus.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6:
        var status_effect := StatusEffect.new()
        var steady_hand := STEADY_HAND_PLUS_STATUS.duplicate()
        status_effect.status = steady_hand
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
