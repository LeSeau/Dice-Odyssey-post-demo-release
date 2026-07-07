extends Card

const DARK_PACT_STATUS = preload("res://statuses/status_dark_pact.tres")

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6:
        var status_effect := StatusEffect.new()
        var dark_pact := DARK_PACT_STATUS.duplicate()
        status_effect.status = dark_pact
        status_effect.execute(targets)
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
