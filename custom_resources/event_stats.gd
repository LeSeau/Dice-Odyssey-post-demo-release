class_name EventStats
extends Resource

@export_range(0, 2) var event_tier: int
@export_range(0.0, 10.0) var weight: float
@export var scene: PackedScene

# Testing-only override: check this on an event's .tres to make it win the draw
# unconditionally, ignoring weight entirely (EventStatsPool.get_random_event_for_tier
# returns it immediately). Meant to be flipped on/off by hand while iterating on one
# event - remember to turn it back off afterward, since this resource is a shared,
# file-backed .tres that persists the flag across runs until you do.
@export var force_for_testing: bool = false

var accumulated_weight: float = 0.0
