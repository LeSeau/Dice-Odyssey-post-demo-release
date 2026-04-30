extends Card

const ENERGIZED_STATUS = preload("res://statuses/energized.tres")

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    
    if Global.roll_history.size() >= 3 :
        var status_effect := StatusEffect.new()
        var energized := ENERGIZED_STATUS.duplicate()
        energized.duration = 1
        status_effect.status = energized
        status_effect.execute(targets)
        Global.blue_dice_bonus_amount += 1

    Events.dice_roll_reset.emit()
