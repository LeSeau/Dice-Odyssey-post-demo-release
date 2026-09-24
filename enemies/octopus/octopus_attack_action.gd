extends EnemyAction



@export var damage := 3
var base_damage = damage

# Capped at two in a row. This used to be a hard `last_action != self` lock, which forced a
# strict A-B-A-B metronome and made the fight fully predictable; the cap keeps it bounded
# without making it a clock.
func is_performable() -> bool:
    return not hit_consecutive_cap(2)

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
