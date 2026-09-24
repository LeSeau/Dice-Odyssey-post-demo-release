extends EnemyAction

# 15 -> 10 (2026-09-06 spice pass): see medusa_gaze_action.gd. This is now the
# quiet beat, not a second spike.
@export var damage := 10
var base_damage = damage

func is_performable() -> bool:
    if enemy.last_action == "medusa_attack" and enemy.last_action_count >= 2:
        return false
    return true

func perform_action() -> void:
    if not enemy or not target:
        return
    
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var target_array: Array[Node] = [target]
    damage_effect.sound = sound
    Global.has_blocked_last_turn = false
    run_attack([damage_effect.execute.bind(target_array)], 0.25, damage_effect.amount)


func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
