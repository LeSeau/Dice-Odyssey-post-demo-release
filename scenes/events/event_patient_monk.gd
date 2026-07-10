extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const HEAL_NOW := 20
const MAX_HP_GAIN := 8

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Pure upside either way (no cost, no risk) - the choice is short-term vs long-term
# value, not safe-vs-risky. Global.player_max_hp is kept in lockstep with
# character_stats.max_health on the bottle path - the top bar's HP label reads
# Global.player_max_hp, not max_health directly, and nothing else in the codebase
# currently changes max_health at runtime, so this sync is easy to miss.
func _on_heal_now_pressed() -> void:
    character_stats.health += HEAL_NOW
    Events.hp_changed.emit()
    Events.event_exited.emit()


func _on_bottle_it_pressed() -> void:
    character_stats.max_health += MAX_HP_GAIN
    Global.player_max_hp += MAX_HP_GAIN
    character_stats.health += MAX_HP_GAIN
    Events.hp_changed.emit()
    Events.event_exited.emit()
