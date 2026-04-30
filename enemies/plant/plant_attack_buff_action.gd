extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

func is_performable() -> bool:
    if enemy.last_action != "plant_attack":
        return false
    return true
    
func perform_action() -> void:
    if not enemy or not target:
        return

    var target_array: Array[Node] = [target]
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 5
    status_effect.status = muscle
    status_effect.sound = sound
    status_effect.execute([enemy])

    
    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
