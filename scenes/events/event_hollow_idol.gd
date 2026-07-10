extends Control

@export var treasure_relic_pool: RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

var character_stats: CharacterStats
var run_stats: RunStats

const MAX_HP_COST := 6
const GOLD_REWARD := 65

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _on_pry_open_pressed() -> void:
    var relic := treasure_relic_pool.get_random_relic(char_stats, relic_handler)
    if not relic:
        _on_melt_pressed()
        return
    character_stats.max_health -= MAX_HP_COST
    Global.player_max_hp -= MAX_HP_COST
    character_stats.health = mini(character_stats.health, character_stats.max_health)
    Events.hp_changed.emit()
    Events.show_reward_with_relic.emit(relic)


func _on_melt_pressed() -> void:
    Global.gold += GOLD_REWARD
    Events.gold_changed.emit()
    Events.event_exited.emit()
