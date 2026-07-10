extends Relic

func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))

func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    # dice.gd increments dice_amount_rolled_this_turn before emitting dice_rolled,
    # so this already reflects the die that was just rolled.
    if Global.dice_amount_rolled_this_turn == 0 or Global.dice_amount_rolled_this_turn % 3 != 0:
        return
    owner.flash()
    Global.roll_value += 2
    Events.change_current_power.emit()

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
