extends Card

const LUCKY_SEVENS_STATUS = preload("res://statuses/status_lucky_sevens.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6:
        var status_effect := StatusEffect.new()
        var lucky_sevens := LUCKY_SEVENS_STATUS.duplicate()
        status_effect.status = lucky_sevens
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
