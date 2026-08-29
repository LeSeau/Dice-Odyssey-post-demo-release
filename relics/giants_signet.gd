extends Relic

# A type-specific relic: worthless without Giant Dice, strong with them. That is the point -
# these belong on the shop shelf, where the player buys one BECAUSE it fits the dice they
# already own, rather than in the treasure pool where an Elf would open a dead chest.
# 10+ on a d12 is a 25% band, so this is a real payout rather than a jackpot.
#
# Pays Block rather than Strength since 2026-08-24 (Julien). Strength compounded - every
# high Giant roll made every later attack better - which made the relic scale absurdly in
# long fights. Block is spent the turn it arrives, so the payout stays flat however long
# the fight runs.

const BLOCK_AMOUNT := 6
const THRESHOLD := 10


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))


func _on_dice_rolled(dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if dice_type != "giant" or Global.last_roll < THRESHOLD:
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
