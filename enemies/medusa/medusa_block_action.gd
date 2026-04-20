extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 9

func is_performable() -> bool:
    # Prevent blocking twice
    if enemy.last_action == "medusa_block":
        return false
    if Global.fight_turn == 0:
        return false
    return true


func perform_action() -> void:
    if not enemy or not target:
        return
    
    var block_effect := BlockEffect.new()
    block_effect.amount = block
    block_effect.sound = sound
    block_effect.execute([enemy])
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 2
    status_effect.status = muscle
    status_effect.execute([enemy])
    Global.has_blocked_last_turn = true
    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
