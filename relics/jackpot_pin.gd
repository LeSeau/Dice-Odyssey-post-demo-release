extends Relic

# The upside half of the Red gamble, opposite Consolation Chip's downside half. Pays in
# Strength rather than damage so it separates from House Money, which fires on the same
# 5-6 band: that one is burst, this one is a build.

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")
const STRENGTH := 2


func initialize_relic(owner: RelicUI) -> void:
    Events.red_dice_rolled.connect(_on_red_dice_rolled.bind(owner))
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))


func _on_red_dice_rolled(owner: RelicUI) -> void:
    if Global.last_roll != 6:
        return
    _grant_strength(owner)


func _on_dice_thrown_landed(dice_type: String, value: int, owner: RelicUI) -> void:
    if dice_type != "red" or value != 6:
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
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
