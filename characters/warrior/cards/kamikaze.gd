extends Card

func _init():
    super._init()
    # This card should target a single enemy by default
    target = Target.SINGLE_ENEMY

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    
    var damage_effect := DamageEffect.new()
    damage_effect.sound = sound
    
    if Global.roll_value > 1:
        # Normal case: damage the targeted enemy
        var base_damage = Global.roll_value * 3
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.execute(targets)
    elif Global.roll_value == 1:
        # Backfire case: damage the player instead
        damage_effect.amount = 6
        
        # Get the player using a reference from your targets
        # Since targets are in the scene, we can access the tree through them
        if not targets.is_empty():
            var tree = targets[0].get_tree()
            var player_targets = tree.get_nodes_in_group("player")
            
            if not player_targets.is_empty():
                print("Backfire! Hero loses 6 HP")
                damage_effect.execute(player_targets)
        else:
            # Fallback if we somehow have no targets
            var player = Global.player
            if player:
                var player_targets: Array[Node] = [player]
                print("Backfire! Hero loses 6 HP")
                damage_effect.execute(player_targets)
    
    Events.dice_roll_reset.emit()
