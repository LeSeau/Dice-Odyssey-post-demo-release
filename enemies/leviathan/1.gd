extends EnemyAction


const INK_STATUS = preload("res://statuses/ink.tres")
const WEAK_STATUS = preload("res://statuses/weak.tres")

var exposed_duration := 2
var ink_duration := 3

# 18 -> 24 (2026-09-06 spice pass): the boss's telegraphed beat, at the boss cap
# (24 = 36% of the 66 HP pool). Its weight drops 5 -> 4 in the AI scene and the
# Crush beat softens 15 -> 11 at weight 6, so expected damage per chance turn barely
# moves (16.5 -> 16.2) while the worst turn goes from 18 to 24. With his +4 Muscle
# guard every 4 turns the third Ink Tide reads 32, which is the fight ending.
#
# ⚠️ Those expected-value figures assume the OLD cap that let this beat repeat. Since
# 2026-09-07 it never fires twice in a row (see is_performable), so the real numbers are
# DPT 15.1 over 6 turns / 14.3 over 8. Raising `damage` here is now the only way to raise
# the worst turn - the repeat is gone as a pressure valve, and it should stay gone: a
# doubled Ink Tide also doubles the hidden-Power window, which is not what this number
# is priced against.
@export var damage := 24
var base_damage = damage

func is_performable() -> bool:
    # NEVER twice in a row (2026-09-07). Was `>= 2`, which allowed exactly two, and that
    # was the "Leviathan hit for 28 twice" report. His guard (2.gd, fight_turn % 4 == 2)
    # hands him a PERMANENT +4 Muscle on turn 2, so from turn 3 on a doubled Ink Tide reads
    # 28/28 = 56 raw against a 66 HP pool. Measured over 200k sims of the real picker: it
    # landed in 25% of 6-8 turn fights, as early as turns 3 & 4. Ink also stacks as DURATION
    # (can_expire = true), so the second cast EXTENDS the hidden Power number to ~6 turns,
    # on exactly the turns you need to block precisely - the pair costs far more than 2x24.
    # Same cap the Bigger Kraken's ink beat already carries, for the same duration reason.
    # Cost: DPT 15.8 -> 15.1 over 6 turns, 14.9 -> 14.3 over 8 (~4.5 raw damage per fight).
    # The ramp is untouched: the SINGLE hit still escalates 24 -> 28 -> 32 as he guards.
    #
    # Uses the shared helper rather than a hardcoded action_id string, so this can no longer
    # silently diverge from `action_id` in leviathan_enemy_ai.tscn.
    return not hit_consecutive_cap(1)

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
