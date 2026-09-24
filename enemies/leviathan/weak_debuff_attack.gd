extends EnemyAction


const EXPOSED_STATUS = preload("res://statuses/exposed.tres")
const WEAK_STATUS = preload("res://statuses/weak.tres")

var exposed_duration := 2
var weak_stacks := 2

# 15 -> 11 (2026-09-06 spice pass): the quiet beat. See 1.gd for the trade.
@export var damage := 11
var base_damage = damage

func is_performable() -> bool:
    # Prevent medium attack from happening 3 times in a row
    if enemy.last_action == "leviathan_weak_attack" and enemy.last_action_count >= 2:
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
    
    run_attack([damage_effect.execute.bind(target_array)], 0.25, damage_effect.amount)
    
    
func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
