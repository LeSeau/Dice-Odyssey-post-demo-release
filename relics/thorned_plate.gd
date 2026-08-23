extends Relic

# A payoff for blocking EXACTLY enough, which is a read the game never rewarded before:
# over-blocking wastes the surplus, under-blocking takes the hit, and only a perfect block
# pays. Pairs with Mortar Trowel without overlapping it (that one rewards over-blocking).

const DAMAGE := 4


func initialize_relic(owner: RelicUI) -> void:
    Events.player_fully_blocked.connect(_on_player_fully_blocked.bind(owner))


func _on_player_fully_blocked(attacker, owner: RelicUI) -> void:
    var target: Node = attacker if is_instance_valid(attacker) else null
    if target == null:
        # No enemy source (a card backfiring, a status tick): fall back to a random enemy so
        # the relic still reads as "thorns" rather than silently doing nothing.
        var enemies := owner.get_tree().get_nodes_in_group("enemies")
        if enemies.is_empty():
            return
        target = enemies[randi() % enemies.size()]
    owner.flash()
    var damage_effect := DamageEffect.new()
    damage_effect.amount = DAMAGE
    damage_effect.execute([target])


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.player_fully_blocked.is_connected(_on_player_fully_blocked):
        Events.player_fully_blocked.disconnect(_on_player_fully_blocked)
