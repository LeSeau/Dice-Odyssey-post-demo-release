extends EnemyAction

# Parity Brothers, beat A. The two alternate with zero randomness: on any given turn exactly
# one brother strikes and the other guards, and they swap every turn (Slate E-1). `turn_parity`
# is the only thing that tells the two apart, so both brothers share this one script and their
# AI scenes differ by a single number.
#
# Strike and guard together form a TOTAL partition of fight_turn % 2 on each brother, which is
# what keeps enemy_action_picker.gd's blind `return get_child(0)` fallback unreachable here -
# the same contract the Skeleton's three-beat cycle relies on.
#
# fight_turn is 0 during PLAYER TURN 1 (player_handler.end_turn() is its only increment), so
# turn_parity 0 strikes on player turns 1, 3, 5...
#
# ⚠ `damage` must keep its SCRIPT default. `var base_damage = damage` runs at class scope,
# BEFORE Godot applies a scene's exported override, so a `damage = 13` line in a .tscn would
# set `damage` and then be ignored by perform_action(). Both brothers hit for the same 13, so
# no scene override is needed. `turn_parity` is safe to export because it is read inside
# is_performable() at runtime, long after the override has landed.
@export var damage := 13
@export var turn_parity := 0
var base_damage = damage


func is_performable() -> bool:
    return Global.fight_turn % 2 == turn_parity


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
    var total_modified_damage := player.modifier_handler.get_modified_value(
        damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)
    intent.current_text = intent.base_text % total_modified_damage
