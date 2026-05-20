extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 5

func is_performable() -> bool:
    return enemy.last_action == "sigil_second_attack"


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
    muscle.stacks = 2
    status_effect.status = muscle
    status_effect.execute([enemy])
    Global.has_blocked_last_turn = true
    reroll_sigil()
    
    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
    
func reroll_sigil() -> void:
    if enemy.status_handler._has_status("sigil"):
        var sigil = enemy.status_handler._get_status("sigil")
        var last = sigil.stacks
        var new_value = randi_range(1, 6)
        while new_value == last:
            new_value = randi_range(1, 6)
        sigil.stacks = new_value
