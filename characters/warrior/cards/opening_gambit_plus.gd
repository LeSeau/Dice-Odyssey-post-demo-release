extends Card

const OPENING_GAMBIT_STATUS = preload("res://statuses/status_opening_gambit.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 4 or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        var opening_gambit := OPENING_GAMBIT_STATUS.duplicate()
        status_effect.status = opening_gambit
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
