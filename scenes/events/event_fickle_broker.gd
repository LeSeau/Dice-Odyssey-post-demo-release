extends Control

@export var treasure_relic_pool: RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

var character_stats: CharacterStats
var run_stats: RunStats

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Blind swap: give up one relic you currently hold (picked at random - you don't
# choose which), get a brand new random one in return. If either side can't
# resolve (no relics held, or the pool has nothing left to offer), the trade
# simply doesn't happen rather than eating your relic for nothing.
func _on_trade_pressed() -> void:
    var relic_uis := relic_handler._get_all_relic_ui_nodes()
    if relic_uis.is_empty():
        Events.event_exited.emit()
        return
    var new_relic := treasure_relic_pool.get_random_relic(char_stats, relic_handler)
    if not new_relic:
        Events.event_exited.emit()
        return
    var traded: RelicUI = relic_uis.pick_random()
    traded.queue_free()
    Events.show_reward_with_relic.emit(new_relic)


func _on_leave_pressed() -> void:
    Events.event_exited.emit()
