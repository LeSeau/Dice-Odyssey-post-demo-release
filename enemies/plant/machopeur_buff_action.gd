extends EnemyAction

const TRUE_STRENGTH_STATUS = preload("res://statuses/true_strength.tres")

func is_performable() -> bool:
    return Global.fight_turn==0

func perform_action() -> void:
    if not enemy or not target:
        returnz

    var target_array: Array[Node] = [target]
    var status_effect := StatusEffect.new()
    var true_strength := TRUE_STRENGTH_STATUS.duplicate()
    true_strength.stacks = 2
    status_effect.status = true_strength
    status_effect.sound = sound
    status_effect.execute([enemy])

    
    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
