class_name RelicPool
extends Resource

@export var pool: Array[Relic] = []

func get_random_relic(character_stats: CharacterStats, relic_handler: RelicHandler, exclude: Array[Relic] = []) -> Relic:
    var available_relics := pool.filter(
        func(relic: Relic):
            var can_appear := relic.can_appear_as_reward(character_stats)
            var already_have := relic_handler.has_relic(relic.id)
            var already_excluded := exclude.has(relic)
            return can_appear and not already_have and not already_excluded
    )

    if available_relics.is_empty():
        return null

    return available_relics.pick_random()
