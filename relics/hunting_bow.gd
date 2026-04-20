class_name BowRelic
extends Relic

# This relic deals 2 damage to a random enemy whenever you roll a 6

func initialize_relic(owner: RelicUI) -> void:
    # Connect to the dice rolled event when the relic is added
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    print("BowRelic: Connected to dice_rolled signal")

func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:
    print("BowRelic: Dice rolled! Type: ", dice_type, " Roll value: ", roll_value, " Last roll: ", Global.last_roll)
    
    # Check the last individual roll, not the cumulative value
    if Global.last_roll != 6:
        print("BowRelic: Not a 6, skipping (rolled ", Global.last_roll, ")")
        return  # Only trigger on a roll of 6
    
    print("BowRelic: Rolled a 6! Dealing damage...")
    
    # Flash the relic UI for feedback
    owner.flash()
    
    # Get all enemies in the scene using the owner's tree
    var enemies = owner.get_tree().get_nodes_in_group("enemies")
    print("BowRelic: Found ", enemies.size(), " enemies")
    
    if enemies.size() == 0:
        return  # No enemies to hit
    
    # Pick a random enemy
    var random_enemy = enemies[randi() % enemies.size()]
    print("BowRelic: Targeting enemy: ", random_enemy.name)
    
    # Create and execute the damage effect
    var dmg = DamageEffect.new()
    dmg.amount = 2
    dmg.execute([random_enemy])
    print("BowRelic: Damage dealt!")

func deactivate_relic(owner: RelicUI) -> void:
    # Disconnect the event when the relic is removed
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
