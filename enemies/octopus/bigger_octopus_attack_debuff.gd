extends EnemyAction


const INK_STATUS = preload("res://statuses/ink.tres")
const WEAK_STATUS = preload("res://statuses/weak.tres")

var exposed_duration := 2
var ink_duration := 2

@export var damage := 4
var base_damage = damage

func is_performable() -> bool:
    return Global.fight_turn == 0 or enemy.last_action == "bigger_octopus_attack"

func perform_action() -> void:
    if not enemy or not target:
        return
    
    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    
    var status_effect := StatusEffect.new()
    var ink := INK_STATUS.duplicate()
    ink.duration = ink_duration
    status_effect.status = ink
    status_effect.execute([target])
    Events.put_ink_on_dice.emit()
    
    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", start, 0.4)
    
    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
    
    
func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
