extends Relic

# Hunting Bow's mirror at the bottom of the die: that one pays on 6s, this one on 1s. Pairs
# with Snake Eyes Charm (Strength on a 1) without overlapping it - one scales, this one is
# immediate chip damage, which is what a Low Roll deck otherwise lacks entirely.
#
# This effect used to live on Needle Die, which was cut on 2026-08-31 (Julien); the Baton
# inherited it rather than the pool losing a low-roll payoff. The Baton's own former effect
# (a Charge for chaining the same die four times) is gone with it.
#
# Reads Global.last_roll, not the signal's roll_value: that argument is the running Power
# total, whereas the face that just landed is what "roll a 1" means. Thrown dice never reach
# here - they do not emit dice_rolled - which is the intended contract for a roll payoff.

const DAMAGE := 3


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    if Global.last_roll != 1:
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
