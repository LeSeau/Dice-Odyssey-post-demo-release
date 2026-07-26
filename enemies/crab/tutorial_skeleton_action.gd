extends EnemyAction

## The tutorial Skeleton's only move. It hits for a modest, blockable amount while the player
## is learning to Block (turns 1-2), then winds up for something far bigger on the final turn.
##
## That last number is the point: turn 3 used to have no stakes at all - the player sat at full
## health against a 6-damage poke, so the finale's "engineer an exact kill" lesson was asking
## for precision nothing actually required. With a hit this size there is no absorbing it, so
## killing him first becomes the only line, and choosing the right roll becomes a real decision.
##
## Deliberately a tutorial-only copy of crab_attack_action.gd rather than an edit of it: that
## script is shared with the real Skeleton fought throughout act 1.

@export var damage := 6
@export var big_hit_damage := 35
## How many attacks this Skeleton must have ALREADY landed before the big one. 2 = the third
## attack, i.e. the one telegraphed on turn 3.
@export var big_hit_after_attacks := 2

## Attacks this enemy has actually resolved. Counted here, and ONLY incremented at the end of
## perform_action(), because the trigger condition has to stay stable across the player's
## end-turn boundary.
##
## The first version keyed off Global.fight_turn and shipped a real bug: fight_turn increments
## inside player_handler.end_turn(), which runs BEFORE the enemy resolves. So turn 2 displayed
## an intent of 6 (computed at fight_turn 1), the player pressed End Turn, fight_turn became 2,
## and the swing landed for 35 - the intent visibly flipped just before impact. Enemy damage
## must never be recomputed from state that can move between "intent shown" and "action
## performed"; this is the same intent-vs-reality divergence documented in CLAUDE.md.
var _attacks_landed := 0


func is_performable() -> bool:
    return true


# EXACTLY the nth attack, not ">=": if the player skips the tutorial, this Skeleton becomes a
# normal fight, and an open-ended threshold would leave it hitting for 35 every turn forever.
# One desperate last swing, then back to normal.
#
# Reads the exports directly instead of caching one into a `base_damage` member the way the
# other enemy actions do - that pattern snapshots the DEFAULT value before the scene's exported
# override is applied, which is a live footgun elsewhere in this codebase.
func _current_damage() -> int:
    return big_hit_damage if _attacks_landed == big_hit_after_attacks else damage


func perform_action() -> void:
    if not enemy or not target:
        return

    var tween := create_tween().set_trans(Tween.TRANS_QUINT)
    var start := enemy.global_position
    var end := target.global_position + Vector2.RIGHT * 32
    var damage_effect := DamageEffect.new()
    var target_array: Array[Node] = [target]
    damage_effect.amount = modifiers.get_modified_value(_current_damage(), Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    tween.tween_property(enemy, "global_position", end, 0.4)
    tween.tween_callback(damage_effect.execute.bind(target_array))
    tween.tween_interval(0.25)
    tween.tween_property(enemy, "global_position", start, 0.4)
    tween.finished.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )
    # Incremented AFTER _current_damage() was read above, so this swing still deals what its
    # intent promised; only the NEXT intent sees the new count.
    _attacks_landed += 1


func update_intent_text() -> void:
    var player := target as Player
    if not player:
        return
    var damage_with_enemy_mods := modifiers.get_modified_value(_current_damage(), Modifier.Type.DMG_DEALT)
    var total_modified_damage := player.modifier_handler.get_modified_value(damage_with_enemy_mods, Modifier.Type.DMG_TAKEN)
    intent.current_text = intent.base_text % total_modified_damage
