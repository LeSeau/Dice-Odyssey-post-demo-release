# Shared placeholder attack for the bench enemies that do not have a real kit yet.
# One simple always-performable lunge so a new enemy can be dropped into a fight and
# behave sanely before its pattern is designed.
#
# DO NOT put per-enemy logic in here - every bench enemy's AI scene points at this same
# file, so editing it changes all of them. When an enemy gets its real pattern, add
# proper action scripts under enemies/<name>/ and repoint that enemy's AI scene.
extends EnemyAction

@export var damage := 8


func is_performable() -> bool:
    # EnemyAction.is_performable() returns false by default, so this has to be explicit
    # or the picker only ever reaches this action through its anti-freeze fallback.
    return true


func perform_action() -> void:
    if not is_instance_valid(enemy) or not is_instance_valid(target):
        return

    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(damage, Modifier.Type.DMG_DEALT)
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
    # A freed target cannot be cast with `as`, it throws instead of returning null.
    if not is_instance_valid(target):
        return
    var player := target as Player
    if not player:
        return
    var damage_with_enemy_mods := modifiers.get_modified_value(damage, Modifier.Type.DMG_DEALT)
    var total := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)
    intent.current_text = intent.base_text % total
