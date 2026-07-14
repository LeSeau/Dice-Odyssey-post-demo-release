extends Card

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 8:
        var status_effect := StatusEffect.new()
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 5
        status_effect.status = muscle
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
