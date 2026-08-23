extends Relic

# Hunting Bow's mirror at the bottom of the die: that one pays on 6s, this one on 1s. Pairs
# with Snake Eyes Charm (Strength on a 1) without overlapping it - one scales, this one is
# immediate chip damage, which is what a Low Roll deck otherwise lacks entirely.

const DAMAGE := 3


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if Global.last_roll != 1:
        return
    _fire(owner)


func _on_dice_thrown_landed(_dice_type: String, value: int, owner: RelicUI) -> void:
    if value != 1:
        return
    _fire(owner)


func _fire(owner: RelicUI) -> void:
    var enemies := owner.get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return
    owner.flash()
    var damage_effect := DamageEffect.new()
    damage_effect.amount = DAMAGE
    damage_effect.execute([enemies[randi() % enemies.size()]])


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
