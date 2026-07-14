extends Card

const LUCKY_STATUS = preload("res://statuses/lucky.tres")

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    var status_effect := StatusEffect.new()
    var lucky := LUCKY_STATUS.duplicate()
    lucky.duration = 2
    status_effect.status = lucky
    status_effect.execute(targets)
    Events.draw_card.emit(2)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.reset_charged_card.emit()
