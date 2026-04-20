extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 6

func is_performable() -> bool:
    # Prevent blocking twice
    if enemy.last_action == "crab_block":
        return false
    return true



func perform_action() -> void:
    if not enemy or not target:
        return
    
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
