class_name EventStatsPool
extends Resource

@export var pool: Array[EventStats]

var total_weights_by_tier := [0.0, 0.0, 0.0]

func _get_all_events_for_tier(tier: int) -> Array[EventStats]:
    return pool.filter(
        func(event: EventStats):
            return event.event_tier == tier
    )

func _setup_weight_for_tier(tier: int) -> void:
    var events := _get_all_events_for_tier(tier)
    total_weights_by_tier[tier] = 0.0

    for event: EventStats in events:
        total_weights_by_tier[tier] += event.weight
        event.accumulated_weight = total_weights_by_tier[tier]

func get_random_event_for_tier(tier: int) -> EventStats:
    var roll := randf_range(0.0, total_weights_by_tier[tier])
    var events := _get_all_events_for_tier(tier)

    for event: EventStats in events:
        if event.accumulated_weight > roll:
            return event
            print(event)

    return null

func setup() -> void:
    for i in 3:
        _setup_weight_for_tier(i)
