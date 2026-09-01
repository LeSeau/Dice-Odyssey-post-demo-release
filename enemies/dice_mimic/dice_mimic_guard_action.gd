extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 5
# The mimic's clock: every guard beat makes every future bite bigger, so a long hostage
# standoff costs more than the dice it withholds.
@export var muscle_rider := 2


# Even beats from turn 3 on (player turns 3, 5, 7...). See dice_mimic_attack_action.gd for
# why the three beats are written as a total partition of fight_turn.
func is_performable() -> bool:
    return Global.fight_turn >= 2 and Global.fight_turn % 2 == 0


func perform_action() -> void:
    if not enemy or not target:
        return

    var block_effect := BlockEffect.new()
    block_effect.amount = block
    block_effect.sound = sound
    block_effect.execute([enemy])

    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = muscle_rider
    status_effect.status = muscle
    status_effect.execute([enemy])
    Events.enemy_strength_changed.emit()

    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )


# Block takes no modifiers (Modifier.Type has no block entry), so the exported value is the
# number shown. Without this override the base class prints base_text verbatim.
func update_intent_text() -> void:
    intent.current_text = intent.base_text % block
