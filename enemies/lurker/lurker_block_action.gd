extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")



func is_performable() -> bool:
    return enemy.last_action == "lurker_first_attack"


func perform_action() -> void:
    if not enemy or not target:
        return

    # Block/buff turns get a body beat too (2026-09-23): see Enemy.play_brace/play_flex.
    enemy.play_flex()
    

    var target_array: Array[Node] = [target]
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 2
    status_effect.status = muscle
    status_effect.execute([enemy])

    
    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
