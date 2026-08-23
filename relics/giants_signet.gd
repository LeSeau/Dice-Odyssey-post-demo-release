extends Relic

# A type-specific relic: worthless without Giant Dice, strong with them. That is the point -
# these belong on the shop shelf, where the player buys one BECAUSE it fits the dice they
# already own, rather than in the treasure pool where an Elf would open a dead chest.
# 10+ on a d12 is a 25% band, so this is a real payout rather than a jackpot.

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")
const STRENGTH := 1
const THRESHOLD := 10


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))


func _on_dice_rolled(dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if dice_type != "giant" or Global.last_roll < THRESHOLD:
        return
    _grant_strength(owner)


func _on_dice_thrown_landed(dice_type: String, value: int, owner: RelicUI) -> void:
    if dice_type != "giant" or value < THRESHOLD:
        return
    _grant_strength(owner)


func _grant_strength(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player == null:
        return
    owner.flash()
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = STRENGTH
    status_effect.status = muscle
    status_effect.execute([player])


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
