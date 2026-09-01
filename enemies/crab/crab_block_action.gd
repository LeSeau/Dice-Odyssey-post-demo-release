extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 6

# Beat 1 of the Skeleton's fixed 3-turn cycle (player turns 2, 5, 8...). The old
# "never block twice in a row" guard is gone because the cycle already guarantees it.
func is_performable() -> bool:
    return Global.fight_turn % 3 == 1



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


# Without this override the base class prints intent.base_text verbatim, and this intent's
# base_text used to be the literal string "6" - so the number on screen was hardcoded and
# ignored the exported block value entirely. base_text is "%s" now and the real value is
# filled in here. Block takes no modifiers (Modifier.Type has no block entry), so there is
# nothing to run it through.
func update_intent_text() -> void:
    intent.current_text = intent.base_text % block
