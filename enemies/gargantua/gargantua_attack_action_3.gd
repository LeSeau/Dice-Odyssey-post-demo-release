extends EnemyAction


const EXPOSED_STATUS = preload("res://statuses/exposed.tres")

var exposed_duration := 3



func is_performable() -> bool:
    if Global.gargantua_debuff_attack_done:
        return false
    if enemy.last_action == "gargantua_second_attack":
        return true
    return false


func perform_action() -> void:
    if not enemy or not target:
        return
    
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.sound = sound
    
    var status_effect := StatusEffect.new()
    var exposed := EXPOSED_STATUS.duplicate()
    exposed.duration = exposed_duration
    status_effect.status = exposed
    status_effect.execute([target])
    Global.gargantua_debuff_attack_done = true
    
    run_attack([damage_effect.execute.bind(target_array)], 0.25, damage_effect.amount)
    
    
func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return
