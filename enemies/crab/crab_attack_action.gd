extends EnemyAction

@export var damage := 6
var base_damage = damage

# Beat 0 of the Skeleton's fixed 3-turn cycle: strike / bone guard / bone spike, repeating.
# fight_turn is 0 during PLAYER TURN 1 (player_handler.end_turn() is the only increment), so
# this lands on player turns 1, 4, 7... The three beats form a total partition of fight_turn
# % 3, which is what makes the picker's blind get_child(0) fallback unreachable here.
func is_performable() -> bool:
    return Global.fight_turn % 3 == 0

func perform_action() -> void:
    if not enemy or not target:
        return
    
    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", start, 0.4)
    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )

func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return
    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)
    intent.current_text = intent.base_text % total_modified_damage
