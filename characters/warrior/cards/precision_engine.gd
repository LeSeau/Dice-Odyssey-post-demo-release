extends Card

const PRECISION_ENGINE_STATUS = preload("res://statuses/status_precision_engine.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6 or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        var precision_engine := PRECISION_ENGINE_STATUS.duplicate()
        status_effect.status = precision_engine
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
