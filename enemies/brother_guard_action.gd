extends EnemyAction

# Parity Brothers, beat B. The mirror of brother_strike_action: the twin who is not striking
# this turn guards instead, and they swap every turn.
#
# ⚠ No Strength on this beat, unlike the Skeleton's guard. The Brothers' ONLY ramp is the
# parity feed (the player's own odd/even faces) plus Rage on a brother's death. Adding a
# per-turn creep here would give the fight a clock the player cannot influence, which is the
# opposite of the encounter: the whole question is that the growth was decided in the dice
# shop, so nothing may grow on its own.
#
# Block takes no modifiers - Modifier.Type has no block entry - so there is nothing to run the
# value through, and update_intent_text prints it directly. Without that override the base
# class would print intent.base_text verbatim, which is the bug that once had the Skeleton's
# guard showing a hardcoded "6" while its exported value said otherwise.
@export var block := 9
@export var turn_parity := 1


func is_performable() -> bool:
    return Global.fight_turn % 2 == turn_parity


func perform_action() -> void:
    if not enemy or not target:
        return

    var block_effect := BlockEffect.new()
    block_effect.amount = block
    block_effect.sound = sound
    block_effect.execute([enemy])

    Global.has_blocked_last_turn = true

    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )


func update_intent_text() -> void:
    intent.current_text = intent.base_text % block
