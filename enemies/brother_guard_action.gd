extends EnemyAction

# Parity Brothers, beat B. The mirror of brother_strike_action: the twin who is not striking
# this turn guards instead, and they swap every turn.
#
# The guard is ALSO the fight's only clock (Julien, 2026-09-14). It hands
# `strength_to_brother` Strength to the OTHER twin, never to itself, so the brother who is
# about to swing is the one who grows and the pair ramps +2 every two turns. That replaces
# the old Rage-on-death payout, which is cut - statuses/brothers_rage.gd is orphaned on disk.
#
# ⚠ The old header here claimed this beat must never grant Strength, on the grounds that the
# brothers' only ramp was the parity FEED. That feed was the first, wrong reading of the
# encounter and has been orphaned since 09-08 (statuses/parity_feed.gd); the live status is
# parity_sensitive, a vulnerability window that grants nothing. Without this rider the fight
# had no clock at all, which is the opposite of the §9 direction. Do not restore that note.
#
# ⚠ Once one twin is down this beat REFUSES ITSELF (Julien, 2026-09-16): the survivor drops
# the guard entirely and strikes every turn instead of blocking into an empty room. So the
# first kill trades the pair's ramp for double the survivor's uptime, rather than making the
# fight go soft. The two beats still form a total partition of the turn - guard is never
# legal while alone, strike always is - so enemy_action_picker's blind get_child(0) fallback
# stays unreachable either way.
#
# ⚠⚠ THE GRANT IS DEFERRED TO Events.enemy_turn_ended, AND IT HAS TO STAY THERE (2026-09-16).
# Granted inline it made the intent lie on one parity in two: Odd Brother is child 0 of the
# fight and the enemy turn walks children in order, so on odd turns this guard resolved BEFORE
# its brother's strike and that strike landed `strength_to_brother` above the number the player
# had just allocated block against. The intent did tick up live off enemy_strength_changed
# while the guard animation played, which is after the decision, so it read as a bug rather
# than as a hand-off. Deferring costs nothing and settles it on both parities: the striker
# always swings at the value on screen, and the buff shows up on the next intent.
#
# Julien's own fix was to make the attacker act first, which lands on the identical damage
# curve (13/13/15/15/17/17 either way). Deferring was chosen only because it is local to this
# file, where reordering means sorting enemy_handler's acting queue for every fight in the game.
#
# Block takes no modifiers - Modifier.Type has no block entry - so there is nothing to run the
# value through, and update_intent_text prints it directly. Without that override the base
# class would print intent.base_text verbatim, which is the bug that once had the Skeleton's
# guard showing a hardcoded "6" while its exported value said otherwise.
const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 6
@export var strength_to_brother := 2
@export var turn_parity := 1


func is_performable() -> bool:
    # Nobody left to guard for, and nobody left to hand Strength to.
    if living_ally() == null:
        return false
    return Global.fight_turn % 2 == turn_parity


func perform_action() -> void:
    if not enemy or not target:
        return

    var block_effect := BlockEffect.new()
    block_effect.amount = block
    block_effect.sound = sound
    block_effect.execute([enemy])

    Global.has_blocked_last_turn = true

    # Queued for the END of the enemy turn, never granted inline. See the header: inline, this
    # rider lands in the middle of the turn, so on the parity where the guard resolves first
    # the twin swings strength_to_brother higher than the intent the player just allocated
    # block against. Deferring makes both parities read the same - what the intent says is what
    # lands, and the buff turns up on the NEXT intent, which the player sees before deciding.
    if not Events.enemy_turn_ended.is_connected(_grant_to_brother):
        Events.enemy_turn_ended.connect(_grant_to_brother, CONNECT_ONE_SHOT)

    get_tree().create_timer(0.6, false).timeout.connect(
        func():
            Events.enemy_action_completed.emit(enemy)
    )


# Resolved here rather than captured when the guard acted: if the twin went down during this
# same enemy turn, nobody is owed anything. That is the same rule as the guard refusing itself
# once it is alone, so killing one brother stops the survivor's growth on every path.
func _grant_to_brother() -> void:
    if enemy == null or not is_instance_valid(enemy):
        return
    var brother := living_ally()
    if brother == null:
        return
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = strength_to_brother
    var status_effect := StatusEffect.new()
    status_effect.status = muscle
    status_effect.execute([brother])
    Events.enemy_strength_changed.emit()


func update_intent_text() -> void:
    intent.current_text = intent.base_text % block
