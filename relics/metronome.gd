extends Relic

# One big payout per fight instead of a trickle every 3rd die (Julien, 2026-08-24): roll 20
# Dice in a fight and every enemy takes 20. Now Rare, and it wants a swarm deck - 20 dice in
# one fight is roughly a five-turn fight at a healthy roll rate, so it is a reward for
# actually building the engine rather than a passive tick.
#
# The old version nudged Power every 3rd roll, which quietly shoved you off Exact/Multiple
# targets you were steering toward. Damage sidesteps that entirely.

const THRESHOLD := 20
const DAMAGE := 20


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    # Thrown dice count too: Global.report_thrown_die_landed increments fight_dice_rolled
    # before emitting, exactly like dice.gd's real-roll path. Both signals are connected
    # because a thrown die is what may carry the count across the line, and it does not
    # emit dice_rolled.
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started.bind(owner))
    _update_counter(owner)


func _on_dice_thrown_landed(dice_type: String, value: int, owner: RelicUI) -> void:
    _on_dice_rolled(dice_type, value, owner)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    # Both roll paths increment fight_dice_rolled BEFORE emitting, so this already counts
    # the die that just landed.
    _update_counter(owner)
    # Exactly 20, not >= 20: the counter only ever steps by one, so this is true on a
    # single roll per fight and needs no "already fired" flag.
    if Global.fight_dice_rolled != THRESHOLD:
        return

    var enemies := owner.get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return
    owner.flash()
    var dmg := DamageEffect.new()
    dmg.amount = DAMAGE
    dmg.execute(enemies)


# Counts toward the payout and stops there, so the player can see how close it is.
func _update_counter(owner: RelicUI) -> void:
    owner.counter.text = str(mini(Global.fight_dice_rolled, THRESHOLD))
    owner.counter.visible = true


func _on_player_turn_started(owner: RelicUI) -> void:
    _update_counter(owner)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
