extends Card

const BLESSED_STATUS = preload("res://statuses/blessed.tres")

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
    if Global.roll_value % 3 == 0:
        var status_effect := StatusEffect.new()
        var blessed := BLESSED_STATUS.duplicate()
        blessed.duration = 1
        status_effect.status = blessed
        status_effect.execute(targets)

        
    if Global.roll_value % 2 == 0: 
        Events.draw_card.emit(2)
    
    Events.dice_roll_reset.emit()

        
    

func _on_dice_rolled():
    print("adding dice to damage")
