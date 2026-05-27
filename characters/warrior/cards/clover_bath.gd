extends Card

const LUCKY_STATUS = preload("res://statuses/lucky.tres")

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:


    var status_effect := StatusEffect.new()
    var lucky := LUCKY_STATUS.duplicate()
    lucky.duration = 1
    status_effect.status = lucky
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
