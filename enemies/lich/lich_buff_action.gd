extends EnemyAction

const ABSORB_STATUS = preload("res://statuses/absorb.tres")

func is_performable() -> bool:
    return Global.fight_turn==0

func perform_action() -> void:
    if not enemy or not target:
        return

    var target_array: Array[Node] = [target]
    var status_effect := StatusEffect.new()
    var absorb := ABSORB_STATUS.duplicate()
    absorb.stacks = 5
    status_effect.status = absorb
    status_effect.sound = sound
    status_effect.execute([enemy])

    
    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
