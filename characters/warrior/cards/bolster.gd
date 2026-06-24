extends Card

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    #Events.reset_charged_card.emit()
    #Events.dice_rolled.connect(_on_dice_rolled)
    #Events.dice_roll_reset.emit()
    #
    #var status_effect := StatusEffect.new()
    #var exposed := EXPOSED_STATUS.duplicate()
    #exposed.duration = exposed_duration
    #status_effect.status = exposed
    #status_effect.execute(targets)
    if Global.roll_value >=  5:
        var status_effect := StatusEffect.new()
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 2
        status_effect.status = muscle
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    

        
    

func _on_dice_rolled():
    print("adding dice to damage")
