extends Relic

# Low rolls stop being dead weight: the bottom two faces pay armour instead of nothing.
# Deliberately small and frequent rather than a big rare payout - it is meant to smooth the
# floor of a Pixie/Green build, not to become a reason to WANT bad rolls.

const BLOCK_AMOUNT := 2


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    # A die is a die (Julien, 2026-07-23): thrown dice count for value-triggered relics.
    # The landed value rides the signal because thrown dice never touch Global.last_roll.
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if Global.last_roll < 1 or Global.last_roll > 2:
        return
    _grant_block(owner)


func _on_dice_thrown_landed(_dice_type: String, value: int, owner: RelicUI) -> void:
    if value < 1 or value > 2:
        return
    _grant_block(owner)


func _grant_block(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player == null:
        return
    owner.flash()
    var block_effect := BlockEffect.new()
    block_effect.amount = BLOCK_AMOUNT
    block_effect.execute([player])


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
