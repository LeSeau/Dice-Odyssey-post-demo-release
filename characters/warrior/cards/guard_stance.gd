extends Card

const GUARD_STANCE_STATUS = preload("res://statuses/status_guard_stance.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6 or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        var guard_stance := GUARD_STANCE_STATUS.duplicate()
        status_effect.status = guard_stance
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
