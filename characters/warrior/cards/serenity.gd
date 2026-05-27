extends Card

const SERENITY_STATUS = preload("res://statuses/serenity_status.tres")

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6:
        var status_effect := StatusEffect.new()
        var serenity := SERENITY_STATUS.duplicate()
        status_effect.status = serenity
        status_effect.execute(targets)
        #Global.bonus_card_draw += 1
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
