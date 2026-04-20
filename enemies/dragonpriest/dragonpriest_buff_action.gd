extends EnemyAction

const CANALIZE_STATUS = preload("res://statuses/canalize.tres")

func is_performable() -> bool:
    return Global.fight_turn==0

func perform_action() -> void:
    if not enemy or not target:
        return

    var target_array: Array[Node] = [target]
    var status_effect := StatusEffect.new()
    var canalize := CANALIZE_STATUS.duplicate()
    canalize.stacks = 5
    status_effect.status = canalize
    status_effect.sound = sound
    status_effect.execute([enemy])

    
    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
