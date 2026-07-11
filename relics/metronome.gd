extends Relic

func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started.bind(owner))
    _update_counter(owner)

func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    # dice.gd increments dice_amount_rolled_this_turn before emitting dice_rolled,
    # so this already reflects the die that was just rolled.
    _update_counter(owner)
    if Global.dice_amount_rolled_this_turn == 0 or Global.dice_amount_rolled_this_turn % 3 != 0:
        return
    owner.flash()
    Global.roll_value += 2
    Events.change_current_power.emit()

# Cycles 1, 2, 3 (trigger), 1, 2, 3 (trigger)... rather than just echoing
# dice_amount_rolled_this_turn % 3 raw, which would show "0" on the roll that
# actually triggers the bonus (n % 3 == 0) instead of the "3" the player expects.
func _update_counter(owner: RelicUI) -> void:
    var n: int = Global.dice_amount_rolled_this_turn
    if n == 0:
        owner.counter.text = "0"
    else:
        owner.counter.text = str(((n - 1) % 3) + 1)
    owner.counter.visible = true

func _on_player_turn_started(owner: RelicUI) -> void:
    _update_counter(owner)

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
