class_name MuscleStatus
extends Status


func initialize_status(target: Node) -> void:
    Events.check_if_losing_strength.connect(_on_check_if_losing_strength.bind(target))
    status_changed.connect(_on_status_changed.bind(target))
    status_changed.emit()  # ← fires once cleanly with correct stacks
    
func _on_status_changed(target: Node) -> void:
    assert(target.get("modifier_handler"), "No modifiers on %s" % target)
    
    var dmg_dealt_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_DEALT)
    assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target) 
    
    var muscle_modifier_value := dmg_dealt_modifier.get_value("muscle")
    
    if not muscle_modifier_value:
        muscle_modifier_value = ModifierValue.create_new_modifier("muscle", ModifierValue.Type.FLAT)
        
    muscle_modifier_value.flat_value = stacks
    dmg_dealt_modifier.add_new_value(muscle_modifier_value)

func _on_check_if_losing_strength(target: Node) -> void:
    # lose_strength_next_turn is a PLAYER-only mechanic (fury.gd, the Octet dice infusion):
    # the signal is global, so every Muscle status in the battle hears it - including ones
    # sitting on ENEMIES (Goblin buffs, act-2 scaling Muscle). Without this owner check, the
    # player's one-turn strength expiring also drained every enemy's Strength by the same
    # amount (even into negatives - Goblin attacking for "0x2").
    if not target.is_in_group("player"):
        return
    if Global.lose_strength_next_turn > 0:
        stacks -= Global.lose_strength_next_turn
