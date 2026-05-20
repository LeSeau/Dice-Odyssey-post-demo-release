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
    
    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.sound = sound
    
    var status_effect := StatusEffect.new()
    var exposed := EXPOSED_STATUS.duplicate()
    exposed.duration = exposed_duration
    status_effect.status = exposed
    status_effect.execute([target])
    Global.gargantua_debuff_attack_done = true
    
    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", start, 0.4)
    
    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
    
    
func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return
