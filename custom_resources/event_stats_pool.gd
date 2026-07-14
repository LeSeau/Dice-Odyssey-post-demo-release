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

func get_random_event_for_tier(tier: int, relic_count: int = -1) -> EventStats:
    var events := _get_all_events_for_tier(tier)

    # Gate out events that need a minimum relic count (e.g. The Crimson Eclipse wagers 2
    # relics) - relic_count < 0 (no count passed) skips this filter entirely. Recomputes the
    # weight total locally from the filtered set instead of using the cached
    # total_weights_by_tier/accumulated_weight (those are computed once over EVERY event in
    # the tier via setup(), regardless of the player's current relic count, which can change
    # between draws).
    var eligible_events: Array[EventStats] = events.filter(
        func(event: EventStats): return relic_count < 0 or relic_count >= event.min_relics_required
    )
    if eligible_events.is_empty():
        return null

    # Testing override: an event flagged force_for_testing wins unconditionally,
    # skipping the weighted roll below entirely. See EventStats.force_for_testing.
    for event: EventStats in eligible_events:
        if event.force_for_testing:
            return event

    var eligible_total_weight := 0.0
    for event: EventStats in eligible_events:
        eligible_total_weight += event.weight

    var roll := randf_range(0.0, eligible_total_weight)
    var cumulative := 0.0
    for event: EventStats in eligible_events:
        cumulative += event.weight
        if cumulative > roll:
            return event

    return null

func setup() -> void:
    for i in 3:
        _setup_weight_for_tier(i)
