extends EnemyAction


const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const WEAK_STATUS = preload("res://statuses/weak.tres")

var exposed_duration := 2
var weak_stacks := 2

# 12 -> 9 (2026-09-06 spice pass): the floor drops so medusa_gaze_action's
# telegraphed 22 can sit at the tier-2 cap without moving her 4-turn attrition.
@export var damage := 9
var base_damage = damage

func is_performable() -> bool:
    if enemy.last_action == "medusa_attack_weak" and enemy.last_action_count >= 2:
        return false
    return true


func perform_action() -> void:
    if not enemy or not target:
        return
    
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    
    var status_effect := StatusEffect.new()
    var weak := WEAK_STATUS.duplicate()
    weak.stacks = weak_stacks
    status_effect.status = weak
    status_effect.execute([target])
    
    run_attack([damage_effect.execute.bind(target_array)],
            0.25, damage_effect.amount, Motion.CAST, Color(0.5, 1.0, 0.35))
    
    
func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
