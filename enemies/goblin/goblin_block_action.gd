extends EnemyAction
const UNLUCKY_STATUS = preload("res://statuses/unlucky.tres")
@export var damage := 5
var base_damage = 5
var unlucky_stacks := 1

func is_performable() -> bool:
    return true

func perform_action() -> void:
    if not enemy or not target:
        return
    
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var target_array: Array[Node] = [target]
    damage_effect.sound = sound
    
    var status_effect := StatusEffect.new()
    var unlucky := UNLUCKY_STATUS.duplicate()
    unlucky.stacks = unlucky_stacks
    status_effect.status = unlucky
    status_effect.execute([target])
    
    run_attack([damage_effect.execute.bind(target_array)], 0.25, damage_effect.amount)
    
func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return
    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)
    intent.current_text = intent.base_text % total_modified_damage
