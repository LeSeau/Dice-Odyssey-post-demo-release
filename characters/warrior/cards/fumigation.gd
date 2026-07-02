extends Card
func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value <= 5:
        
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
            damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
            damage_effect.execute(live_targets)
            
            if i < hit_count - 1:
                await tree.create_timer(0.7).timeout
        
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Deal ? damage to all enemies, once per enemy"
    if not has_active_roll() or not meets_requirement():
        return "Deal X damage to all enemies, once per enemy"
    var total := modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
    return "Deal %d damage to all enemies, once per enemy" % total
