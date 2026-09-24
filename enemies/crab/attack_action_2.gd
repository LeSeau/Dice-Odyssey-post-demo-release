extends EnemyAction

@export var damage := 12
var base_damage = damage

# Beat 2 of the Skeleton's fixed 3-turn cycle (player turns 3, 6, 9...). Was % 4 == 3, i.e.
# every 4th turn, back when the other two beats were a weighted coin flip. The spike is now
# fully telegraphed on a schedule the player can read from turn one, which is the whole point
# of the fight: the turn-2 guard soaks a hit and slows your kill, pushing you into this.
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
