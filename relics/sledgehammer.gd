extends Relic

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

var triggerable = true

func initialize_relic(owner: RelicUI) -> void:
    # Connect to the dice rolled event when the relic is added
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.change_current_power.connect(_on_change_current_power.bind(owner))
    print("initializing sledgehammer")
func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:
    print("sledgehammer is listening to dice rolls")
    if Global.roll_value > 10 and triggerable:  
        owner.flash()
        var status_effect := StatusEffect.new()
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 1
        status_effect.status = muscle
        var player := owner.get_tree().get_first_node_in_group("player") as Player
        if player:
            status_effect.execute([player])
        triggerable = false
    elif Global.roll_value < 5: 
        triggerable = true
        
func _on_change_current_power(owner: RelicUI) -> void:
    if Global.roll_value > 10 and triggerable:  
        owner.flash()
        var status_effect := StatusEffect.new()
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 1
        status_effect.status = muscle
        var player := owner.get_tree().get_first_node_in_group("player") as Player
        if player:
            status_effect.execute([player])
        triggerable = false
    elif Global.roll_value < 5: 
        triggerable = true
func deactivate_relic(owner: RelicUI) -> void:
    print("deactivating sledgehammer")
    # Disconnect the event when the relic is removed
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.change_current_power.is_connected(_on_change_current_power):
        Events.change_current_power.disconnect(_on_change_current_power)
