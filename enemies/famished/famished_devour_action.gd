extends EnemyAction

@export var damage := 13
var base_damage = damage


# Beat 2 of the cycle - the telegraphed spike. Blocking it costs Dice, and spending Dice is
# exactly what feeds its Gorge status. That tension is the fight.
func is_performable() -> bool:
    return Global.fight_turn % 3 == 2

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
