extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 5

func is_performable() -> bool:
    return enemy.last_action == "defender_double_attack"


func perform_action() -> void:
    if not enemy or not target:
        return

    # Block/buff turns get a body beat too (2026-09-23): see Enemy.play_brace/play_flex.
    enemy.play_brace(true)
    
    var block_effect := BlockEffect.new()
    block_effect.amount = block
    block_effect.sound = sound
    block_effect.execute([enemy])
    var target_array: Array[Node] = [target]
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 1
    status_effect.status = muscle
    status_effect.execute([enemy])
    Global.has_blocked_last_turn = true
    
    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
