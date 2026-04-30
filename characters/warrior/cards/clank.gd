extends Card
func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
   
    if Global.roll_value <= 7:
        Events.reset_charged_card.emit()
        
        var tree = targets[0].get_tree()
        
        for i in range(2):
            var damage_effect = DamageEffect.new()
            var base_damage = Global.roll_value
            damage_effect.sound = sound
            
            damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
            damage_effect.execute(targets)
            
            if i == 0:
                await tree.create_timer(0.7).timeout
                # Safety check: bail if target died from first hit
                var still_alive = targets.filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
                if still_alive.size() == 0:
                    break
                targets = still_alive
        
        Events.dice_roll_reset.emit()
