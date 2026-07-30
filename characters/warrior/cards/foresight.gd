extends Card

const FORESIGHT_STATUS = preload("res://statuses/status_foresight.tres")

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if meets_requirement():
        var status_effect := StatusEffect.new()
        var foresight := FORESIGHT_STATUS.duplicate()
        status_effect.status = foresight
        status_effect.execute(targets)
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
