extends EnemyAction

@export var damage := 4
var base_damage = damage


# Every turn after the steal. Together with the steal's `fight_turn == 0` this is a total
# partition of fight_turn, which is what keeps the picker's blind get_child(0) fallback
# unreachable.
#
# The mimic has no guard beat and no Strength on purpose (2026-09-02): it is a throughput tax,
# not a damage body, and its fight-mate carries the clock. One clock per fight.
func is_performable() -> bool:
    return Global.fight_turn >= 1


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
