extends EnemyAction

# The Dicelord's signature move (2026-07-28) - act 2 ONLY. This AI scene is shared with the
# act-1 Leviathan, which must keep its classic kit, so the act gate lives in is_performable.
# CONDITIONAL on a fixed cadence (every 3rd turn, never turn 0): deterministic triggers are
# auto-telegraphed by the intent UI showing next actions, same pattern as the Crab spike.
#
# Effect: hits for `damage` (act-2 flat bonus applies through DMG_DEALT like every attack)
# and STEALS a die - one random owned type gets -1 next turn via the bonus_amount route:
# dice_interface refills current = max + bonus at turn start then zeroes the bonus, so the
# theft lasts exactly one turn (same plumbing as Depleted / Dice Bag).

const STEALABLE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]

@export var damage := 10
var base_damage = damage


func is_performable() -> bool:
    return Global.current_act >= 2 and Global.fight_turn % 3 == 1


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

    _steal_random_die()

    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", start, 0.4)
    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )


func _steal_random_die() -> void:
    var owned: Array[String] = []
    for dice_type in STEALABLE_TYPES:
        if int(Global.get("%s_dice_max_amount" % dice_type)) > 0:
            owned.append(dice_type)
    if owned.is_empty():
        return
    var stolen: String = owned[randi() % owned.size()]
    var prop := "%s_dice_bonus_amount" % stolen
    Global.set(prop, int(Global.get(prop)) - 1)


func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return
    var damage_with_enemy_mods := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)
    intent.current_text = intent.base_text % total_modified_damage
