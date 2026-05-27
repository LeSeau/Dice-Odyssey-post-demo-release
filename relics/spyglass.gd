extends Relic

func initialize_relic(owner: RelicUI) -> void:
    # Connect to the red dice rolled event when the relic is added
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.change_current_power.connect(_on_change_current_power.bind(owner))

func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:
    if Global.roll_value == 10:  # or use the roll_value parameter
        print("spyglass activated - power hit 10")
        owner.flash()
        var oracle_card = load("res://characters/warrior/cards/card_oracle_exhaust.tres")
        Events.add_card_to_hand_requested.emit(oracle_card)   
        
func _on_change_current_power(owner: RelicUI) -> void:
    print("spyglass ok change current power")
    if Global.roll_value == 10:
        owner.flash()  # Visual feedback that the relic activated
        var oracle_card = load("res://characters/warrior/cards/card_oracle_exhaust.tres")
        Events.add_card_to_hand_requested.emit(oracle_card)   
    

func deactivate_relic(owner: RelicUI) -> void:
    # Disconnect the event when the relic is removed
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.change_current_power.is_connected(_on_change_current_power):
        Events.change_current_power.disconnect(_on_change_current_power)
