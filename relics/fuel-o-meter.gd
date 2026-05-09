extends Relic

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")


func initialize_relic(owner: RelicUI) -> void:
    # Connect to the red dice rolled event when the relic is added
    Events.refuel_happened.connect(_on_refuel_happened.bind(owner))


func _on_refuel_happened(amount:int, owner: RelicUI) -> void:
    if amount > 9:  
        owner.flash()
        var status_effect := StatusEffect.new()
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 2
        status_effect.status = muscle
        var player := owner.get_tree().get_first_node_in_group("player") as Player
        if player:
            status_effect.execute([player])

        

#func deactivate_relic(owner: RelicUI) -> void:
    ## Disconnect the event when the relic is removed
    #if Events.dice_rolled.is_connected(_on_dice_rolled):
        #Events.dice_rolled.disconnect(_on_dice_rolled)
    #if Events.change_current_power.is_connected(_on_change_current_power):
        #Events.change_current_power.disconnect(_on_change_current_power)
