extends Relic

func initialize_relic(owner: RelicUI) -> void:
    # Connect to the red dice rolled event when the relic is added
    Events.red_dice_rolled.connect(_on_red_dice_rolled.bind(owner))

func _on_red_dice_rolled(owner: RelicUI) -> void:
    # Check if this is a red dice roll and boost the value
    if Global.dice_type == "red":
        owner.flash()  # Visual feedback that the relic activated
        Global.roll_value += 2
        Events.change_current_power.emit()  # Update the display
        print("Red dice boosted by 2!")

func deactivate_relic(owner: RelicUI) -> void:
    # Disconnect the event when the relic is removed
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
