extends EnemyAction

## PETRIFYING GAZE - the telegraphed spike (2026-09-06 spice pass, step 1 of
## act1_act2_encounter_plan_2026-09.md).
##
## Medusa used to be two weighted hits in a narrow band (12 + Weak 2, and 15) plus the guard,
## so every turn of hers landed at 12-15 and nothing read as a wind-up. The two chance beats
## are now softened to 9 and 10, and this fires on a fixed cadence at the tier-2 spike cap
## (22 = 33% of the 66 HP pool). Her 4-turn attrition is held flat on purpose: it was
## ~40.9 (three chance turns at ~13.6), it is now ~41 (two chance turns at ~9.5, plus 22).
## Raise the spike, lower the floor, leave the ledger alone.
##
## CADENCE: fight_turn % 4 == 2, i.e. the third turn of each cycle, with medusa_block_action's
## guard on % 4 == 3 immediately after. The shape is soft, soft, GAZE, guard. Different
## residues mod 4, so the two conditionals can never both be performable on the same turn.
##
## The guard hands her +3 Muscle every cycle, so the second gaze reads 25 and the third 28.
## That ramp IS her clock - the spike cap is on the RAW number, and a late-fight beat carried
## past it by her own Strength is the fight ending, not a violation.
@export var damage := 22
var base_damage = damage


func is_performable() -> bool:
    return Global.fight_turn % 4 == 2


func perform_action() -> void:
    if not enemy or not target:
        return

    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var target_array: Array[Node] = [target]
    damage_effect.sound = sound
    Global.has_blocked_last_turn = false

    # A longer wind-up than her other beats: this is the one the player is meant to see
    # coming and answer, so it gets its own beat of anticipation before the lunge.
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", end, 0.35)
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
