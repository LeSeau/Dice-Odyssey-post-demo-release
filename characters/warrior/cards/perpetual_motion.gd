extends Card

const PERPETUAL_MOTION_STATUS = preload("res://statuses/status_perpetual_motion.tres")

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6 or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        var perpetual_motion := PERPETUAL_MOTION_STATUS.duplicate()
        status_effect.status = perpetual_motion
        status_effect.execute(targets)
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
