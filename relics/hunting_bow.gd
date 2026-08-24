class_name BowRelic
extends Relic

# Deals 3 damage to a random enemy whenever you roll a 6 (was 5, nerfed 2026-08-24:
# thrown 6s feed it too, so Cursed Toss's 75%-sixes Evil die was turning it into a
# per-turn nuke rather than a trickle).

func initialize_relic(owner: RelicUI) -> void:
    # Connect to the dice rolled event when the relic is added
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    # Thrown 6s fire the bow too (Julien, 2026-07-23) - Cursed Toss's Evil die (75% sixes)
    # is the big feeder. The landed value rides the signal (thrown dice never set last_roll).
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))
    print("BowRelic: Connected to dice_rolled signal")
    print("initialize_relic called for ", relic_name)
func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:

    # Check the last individual roll, not the cumulative value
    if Global.last_roll != 6:
        return  # Only trigger on a roll of 6

    _fire_arrow(owner)

func _on_dice_thrown_landed(_dice_type: String, value: int, owner: RelicUI) -> void:
    if value != 6:
        return
    _fire_arrow(owner)

func _fire_arrow(owner: RelicUI) -> void:

    # Flash the relic UI for feedback
    owner.flash()

    # Get all enemies in the scene using the owner's tree
    var enemies = owner.get_tree().get_nodes_in_group("enemies")

    if enemies.size() == 0:
        return  # No enemies to hit

    # Pick a random enemy
    var random_enemy = enemies[randi() % enemies.size()]

    # Create and execute the damage effect
    var dmg = DamageEffect.new()
    dmg.amount = 3
    dmg.execute([random_enemy])

func deactivate_relic(owner: RelicUI) -> void:
    # Disconnect the event when the relic is removed
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
    print("bow was deactivated")
