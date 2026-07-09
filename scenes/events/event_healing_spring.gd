extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const DRINK_HEAL := 25
const FLASK_HEAL := 10
const FLASK_GOLD := 25

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _on_drink_pressed() -> void:
    character_stats.health += DRINK_HEAL
    Events.hp_changed.emit()
    Events.event_exited.emit()


func _on_flask_pressed() -> void:
    character_stats.health += FLASK_HEAL
    Global.gold += FLASK_GOLD
    Events.hp_changed.emit()
    Events.gold_changed.emit()
    Events.event_exited.emit()
