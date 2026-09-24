extends EnemyAction



# 12 -> 13 (2026-08-18 audit): tier-2 solo DPT was measured under the target curve.
@export var damage := 13
var base_damage = damage

func is_performable() -> bool:
    return enemy.last_action != "vortex_attack" or Global.fight_turn == 0

func perform_action() -> void:
    if not enemy or not target:
        return
    
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound

    run_attack([damage_effect.execute.bind(target_array)], 0.25, damage_effect.amount)

func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
