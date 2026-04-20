extends Card

const ENERGIZED_STATUS = preload("res://statuses/energized.tres")
const LUCKY_STATUS = preload("res://statuses/lucky.tres")

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:

    if Global.roll_value >= 12:
        var status_effect := StatusEffect.new()
        var energized := ENERGIZED_STATUS.duplicate()
        energized.duration = 1
        status_effect.status = energized
        status_effect.execute(targets)
        Global.blue_dice_bonus_amount += 1
        
        var status_effect2 := StatusEffect.new()
        var lucky := LUCKY_STATUS.duplicate()
        lucky.duration = 1
        status_effect2.status = lucky
        status_effect2.execute(targets)
        
        var block_effect := BlockEffect.new()
        block_effect.amount = Global.roll_value
        block_effect.sound = sound
        block_effect.execute(targets)
        Events.dice_roll_reset.emit()
