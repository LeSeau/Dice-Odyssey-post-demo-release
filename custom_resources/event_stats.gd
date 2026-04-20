class_name EventStats
extends Resource

@export_range(0, 2) var event_tier: int
@export_range(0.0, 10.0) var weight: float
@export var scene: PackedScene

var accumulated_weight: float = 0.0
