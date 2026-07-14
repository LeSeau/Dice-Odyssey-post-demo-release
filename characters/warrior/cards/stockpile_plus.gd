extends Card

const STOCKPILE_PLUS_STATUS = preload("res://statuses/status_stockpile_plus.tres")

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6 or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        var stockpile := STOCKPILE_PLUS_STATUS.duplicate()
        status_effect.status = stockpile
        status_effect.execute(targets)
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
