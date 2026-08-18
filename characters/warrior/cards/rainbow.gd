extends Card

const LOADED_STATUS = preload("res://statuses/loaded.tres")

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
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
        var loaded := LOADED_STATUS.duplicate()
        loaded.stacks = 1
        status_effect.status = loaded
        status_effect.execute(targets)

        
    if Global.roll_value % 2 == 0 && Global.roll_value % 3 == 0: 
        var active_dice = Global.dice_type
        var dice_amount_variable = active_dice + "_dice_current_amount"
        
        # Check if the variable exists in Global
        if dice_amount_variable in Global:
            # Update the corresponding amount dynamically
            var current_amount = Global.get(dice_amount_variable)
            Global.set(dice_amount_variable, current_amount + 1)
            
            Events.change_current_power.emit()
            Events.dice_roll_reset.emit()
            Events.reset_charged_card.emit()
            Events.dice_amount_changed.emit()
            
            var support_effect := SupportEffect.new()
            support_effect.sound = sound
            support_effect.execute(targets)
            Events.dice_charged.emit(active_dice, 1)
    
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
        
    

func _on_dice_rolled():
    print("adding dice to damage")
