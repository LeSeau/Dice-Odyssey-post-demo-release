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

    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    run_attack([damage_effect.execute.bind(target_array)], 0.25, damage_effect.amount)


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
