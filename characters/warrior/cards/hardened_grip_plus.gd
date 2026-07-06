extends Card

const HARDENED_GRIP_STATUS = preload("res://statuses/status_hardened_grip.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 4:
        var status_effect := StatusEffect.new()
        var hardened_grip := HARDENED_GRIP_STATUS.duplicate()
        status_effect.status = hardened_grip
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
