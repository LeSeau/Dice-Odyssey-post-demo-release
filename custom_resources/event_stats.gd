class_name EventStats
extends Resource

@export_range(0, 2) var event_tier: int
@export_range(0.0, 10.0) var weight: float
@export var scene: PackedScene

# Some events only make sense with a minimum relic count (e.g. The Crimson Eclipse wagers 2
# relics) - below this, the event still wouldn't crash (its own logic clamps to however many
# relics you actually own) but offering it at all is a bad/confusing draw. 0 = no gate.
@export var min_relics_required: int = 0

# Some events SPEND a specific die (The Dice Machine melts a Blue, The Hollow Idol is fed a
# Red). Since the run-start loadout picker (2026-08-13) a run can legitimately own zero Blue
# and/or zero Red, so those events have to be gated out of the draw entirely - one of the
# player's few event rooms otherwise turns into a dead screen, and the handler would happily
# push the count to -1. "" = no gate. Must be one of Global.DICE_TYPE_ORDER.
# NOTE: the events also guard themselves at runtime, so this gate failing open (e.g. a .tres
# re-saved by an editor that hadn't picked up this property yet) degrades to "offered but
# harmless" rather than to a negative dice count.
@export var required_dice_type: String = ""

# Testing-only override: check this on an event's .tres to make it win the draw
# unconditionally, ignoring weight entirely (EventStatsPool.get_random_event_for_tier
# returns it immediately). Meant to be flipped on/off by hand while iterating on one
# event - remember to turn it back off afterward, since this resource is a shared,
# file-backed .tres that persists the flag across runs until you do.
@export var force_for_testing: bool = false


var accumulated_weight: float = 0.0
