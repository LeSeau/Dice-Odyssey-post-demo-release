extends Card

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    if Global.roll_value == 1 :
        var status_effect := StatusEffect.new()
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 2
        status_effect.status = muscle
        status_effect.execute(targets)
        status_effect.sound = sound

    Events.reset_charged_card.emit()
    Global.roll_value=6
    Events.change_current_power.emit()
    Global.player_hp -= 3
    Events.stats_changed.emit() #NOT WORKING

    
