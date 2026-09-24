extends EnemyAction

@export var damage := 7
@onready var modifier_handler: ModifierHandler = $"../ModifierHandler"



var base_damage = damage

func is_performable() -> bool:
    if enemy.last_action != "oculus_buff":
        return false
    return true

func perform_action() -> void:
    if not enemy or not target:
        return
    
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    print("modified damage is:", damage_effect.amount)
    

    var target_array: Array[Node] = [target]
    damage_effect.amount = damage_effect.amount
    damage_effect.sound = sound
    
    run_attack([damage_effect.execute.bind(target_array)],
            0.35, damage_effect.amount, Motion.CAST, Color(1.0, 0.45, 0.3))

func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
