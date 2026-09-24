extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var damage := 6
# Taking the small hit is how it grows: this is the whole choice the fight offers itself.
@export var muscle_rider := 2
var base_damage = damage


func is_performable() -> bool:
    return not hit_consecutive_cap(2)

func perform_action() -> void:
    if not enemy or not target:
        return

    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound

    # Strength lands with the hit, so the intent number stays honest for THIS swing.
    run_attack([damage_effect.execute.bind(target_array), _apply_muscle_rider],
            0.25, damage_effect.amount)


func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage


func _apply_muscle_rider() -> void:
    if muscle_rider <= 0 or not is_instance_valid(enemy):
        return
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = muscle_rider
    status_effect.status = muscle
    status_effect.execute([enemy])
    Events.enemy_strength_changed.emit()
