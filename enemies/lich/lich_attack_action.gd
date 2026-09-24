extends EnemyAction

@export var damage := 8
@onready var modifier_handler: ModifierHandler = $"../ModifierHandler"



var base_damage = damage


# Explicit (2026-08-18 honesty pass). EnemyAction.is_performable() returns FALSE by default,
# so this steady attack was only ever reached through the picker's anti-freeze
# `get_child(0)` fallback. Behaviour is unchanged - this IS child 0 - but the Lich's main
# attack no longer depends on a safety net, and reordering the AI's children can no longer
# silently change what it does.
func is_performable() -> bool:
    return true


func perform_action() -> void:
    if not enemy or not target:
        return
    
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    

    var target_array: Array[Node] = [target]
    damage_effect.amount = damage_effect.amount
    damage_effect.sound = sound
    
    run_attack([damage_effect.execute.bind(target_array)],
            0.35, damage_effect.amount, Motion.CAST, Color(0.72, 0.45, 1.0))

func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
