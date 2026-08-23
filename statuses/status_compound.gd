class_name CompoundStatus
extends Status

# Display-only badge for the carried-Power promise (Global.starting_power_next_turn).
#
# Compound used to be "next turn, draw 2 and Charge 2 Blue Dice", which was a real
# START_OF_TURN payout living in this script. The 2026-08-20 review turned it into
# "start your next turn with N Power", and that payout moved into dice.gd
# (_on_player_turn_started consumes starting_power_next_turn) - which left the card
# with nothing on screen at all. This badge puts the pending promise back in front of
# the player; it pays out nothing itself.
#
# Lifecycle is the same one the old payout status had: START_OF_TURN + can_expire +
# duration 1. player_turn_started (where dice.gd hands over the Power) fires BEFORE the
# tweened relic -> status cascade that calls apply_status(), so the badge always clears
# on the very turn its Power lands.

const BADGE_PATH := "res://statuses/status_compound.tres"


# `delta` is how much this play actually ADDED to the promise, not what it promised:
# the writers use maxi(), so a second Compound on the same turn adds nothing, while
# Compound after Compound+ adds the difference. StatusHandler.add_status() stacks
# INTENSITY statuses additively, so feeding it the delta makes the badge track
# Global.starting_power_next_turn exactly instead of drifting above it.
#
# load() rather than preload(): this script is the one attached to BADGE_PATH, and
# preloading your own scene/resource at script scope deadlocks Godot's loader.
static func show_promise(targets: Array[Node], delta: int) -> void:
    if delta <= 0:
        return
    var badge: Status = (load(BADGE_PATH) as Status).duplicate()
    badge.stacks = delta
    var status_effect := StatusEffect.new()
    status_effect.status = badge
    status_effect.execute(targets)


func apply_status(_target: Node) -> void:
    # By the time this runs, dice.gd has already consumed the promise this turn. A value
    # still sitting in the global therefore means a NEW promise was made in the sliver
    # between player_turn_started and this cascade - keep the badge alive for it (the +1
    # cancels the -= 1 StatusHandler._on_status_applied is about to do) and re-sync the
    # number, so the badge can never outlive or under-report the real promise.
    if Global.starting_power_next_turn > 0:
        stacks = Global.starting_power_next_turn
        duration += 1
    status_applied.emit(self)
