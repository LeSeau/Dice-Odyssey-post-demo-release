extends Card
func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if meets_requirement():
        
        var hit_count = targets.size()
        
        if hit_count == 0:
            return
        
        var tree = targets[0].get_tree()
        var live_targets = targets.duplicate()
        
        for i in range(hit_count):
            live_targets = live_targets.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())
            
            if live_targets.size() == 0:
                break
            
            var damage_effect = DamageEffect.new()
            damage_effect.sound = sound
            # Waves after the first land past the Berserker window; bake the boost in.
            var raw := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
            damage_effect.amount = raw if i == 0 else Card.deferred_berserker_damage(raw)
            damage_effect.execute(live_targets)
            
            if i < hit_count - 1:
                await tree.create_timer(0.7).timeout
        
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "For each enemy, deal ? damage to ALL enemies"
    if not has_active_roll() or not meets_requirement():
        return "For each enemy, deal X damage to ALL enemies"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "For each enemy, deal X damage to ALL enemies (%d)" % total
