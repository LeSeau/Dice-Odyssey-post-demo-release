class_name SurgeStatus
extends Status

# SURGE N: every Dice roll gains +N Power. The game's second scaling axis alongside Strength
# (Julien, 2026-08-16) - Strength scales per HIT, Surge scales per ROLL, so they reward
# opposite decks and never collapse into each other.
#
# Named "Loaded" until 2026-08-28. Dropped because "loaded dice" means RIGGED - a predetermined
# result - which is what Lucky already does; the mechanic is a flat bonus, not a fixed face.
#
# Replaces the dormant "Infused" status, which was a one-shot "+2 to your next roll" (i.e. a
# second Boost) and was only reachable from Rainbow, a card that isn't even in the pool. The
# name had to change anyway because it collided with the act-2 Dice Infusion system.
#
# This resource is the BADGE ONLY - the effect lives in Global.surge_amount because dice.gd
# reads it inside _apply_roll_result on every roll. Same display-status / global-effect split
# Emanation already uses.
#
# START_OF_TURN so the turn-scoped slice ("Gain Surge 2 this turn") can expire and the badge
# resync without a card being played. can_expire is false - this never times out on its own,
# it only ever mirrors the global - and hide_when_zero drops the icon once nothing is left.


func apply_status(_target: Node) -> void:
    if Global.surge_expiring > 0:
        Global.surge_amount = max(0, Global.surge_amount - Global.surge_expiring)
        Global.surge_expiring = 0
    # Re-sync rather than trusting the accumulated badge: StatusHandler.add_status() stacks the
    # delta when a card grants Surge, but only this line can take the count back DOWN when a
    # turn-scoped slice ends.
    stacks = Global.surge_amount
    status_applied.emit(self)
