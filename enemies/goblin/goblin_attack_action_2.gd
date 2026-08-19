extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var damage := 9
# 7 -> 9 (2026-08-18 audit): the second beat is the spike of the Goblin loop.
# NOTE: this hardcoded value is what actually runs - the @export above is never read.
# Ramp rider (2026-08-18 audit Wave A): the spike beat also grants +1 Strength.
@export var muscle_rider := 1

var base_damage =  9

func is_performable() -> bool:
    return enemy.last_action == "goblin_attack"


func perform_action() -> void:
    if not enemy or not target:
        return
    
    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    print("modified damage is:", damage_effect.amount)

    var target_array: Array[Node] = [target]
    damage_effect.amount = damage_effect.amount
    damage_effect.sound = sound
    
    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    # Strength lands with the hit so the displayed intent stays true for THIS swing.
    tween.tween_callback(_apply_muscle_rider)
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", start, 0.4)
    
    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )

func _apply_muscle_rider() -> void:
    if muscle_rider <= 0 or not is_instance_valid(enemy):
        return
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = muscle_rider
    status_effect.status = muscle
    status_effect.execute([enemy])


func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    # This action hits twice (see perform_action's two damage_effect.execute calls, both for
    # the same base_damage) - shown as "2xN" (per-hit damage, same pattern as Temple Defender's
    # defender_attack_action_2.gd) rather than the combined total, so the player can tell at a
    # glance it's two separate strikes instead of one big hit.
    intent.current_text = intent.base_text % total_modified_damage
