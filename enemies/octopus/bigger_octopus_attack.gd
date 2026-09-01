extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var damage := 7
# Ramp rider (2026-08-18 audit Wave A): this beat also grants +1 Strength so the fight
# carries a clock. Rides an existing beat, one rule per fight. The AI scene is shared by
# all three tier .tres files, so this single edit covers every Bigger Kraken fight.
@export var muscle_rider := 1
# See bigger_octopus_attack_debuff.gd: -1 = ordinary chance beat, >= 0 = guaranteed opener
# on that fight_turn. Turn 2 is a guaranteed crush.
@export var opener_turn: int = -1
var base_damage = damage

# Was hard-locked to "only right after an ink blast", which forced a strict ink-crush
# metronome. Now a plain 50/50 beat capped at two in a row.
func is_performable() -> bool:
    if opener_turn >= 0:
        return Global.fight_turn == opener_turn
    return not hit_consecutive_cap(2)

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

    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    # Strength lands with the hit: the intent number stays honest for THIS swing.
    tween.tween_callback(_apply_muscle_rider)
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", start, 0.4)
    
    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )

func _apply_muscle_rider() -> void:
    if muscle_rider <= 0 or not is_instance_valid(enemy):
        return
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = muscle_rider
    status_effect.status = muscle
    status_effect.execute([enemy])


func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return

    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)

    intent.current_text = intent.base_text % total_modified_damage
