extends Card
const DEPLETED_STATUS = preload("res://statuses/depleted.tres")
func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if Global.roll_value <= 8:
        var status_effect := StatusEffect.new()
        var depleted := DEPLETED_STATUS.duplicate()
        depleted.duration = 1
        status_effect.status = depleted
        
        var player_targets = targets[0].get_tree().get_nodes_in_group("player")
        status_effect.execute(player_targets)
        
        Global.blue_dice_bonus_amount -= 1
        
        var tree = targets[0].get_tree()
        
        var enemies = []
        for e in tree.get_nodes_in_group("enemies"):
            if is_instance_valid(e):
                enemies.append(e)
        
        if enemies.size() == 0:
            return
        
        for i in range(2):
            var random_enemy = enemies[randi() % enemies.size()]
            
            var damage_effect = DamageEffect.new()
            var base_damage = Global.roll_value
            damage_effect.sound = sound
            if Global.dice_type == "red":
                base_damage += 1
            
            damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
            damage_effect.execute([random_enemy])
            
            if i == 0:
                await tree.create_timer(0.7).timeout
                # Re-query live enemies from scene
                enemies = []
                for e in tree.get_nodes_in_group("enemies"):
                    if is_instance_valid(e):
                        enemies.append(e)
                if enemies.size() == 0:
                    break
        
        Events.dice_roll_reset.emit()
