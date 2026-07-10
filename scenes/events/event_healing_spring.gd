extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const DRINK_COST := 25
const DRINK_HEAL := 25
const FLASK_HEAL := 10
const BLEED_HP_COST := 10
const BLEED_GOLD := 40

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _on_drink_pressed() -> void:
    if Global.gold < DRINK_COST:
        return
    Global.gold -= DRINK_COST
    character_stats.health += DRINK_HEAL
    Events.gold_changed.emit()
    Events.hp_changed.emit()
    Events.event_exited.emit()


func _on_flask_pressed() -> void:
    character_stats.health += FLASK_HEAL
    Events.hp_changed.emit()
    Events.event_exited.emit()


func _on_bleed_pressed() -> void:
    character_stats.health -= BLEED_HP_COST
    Global.gold += BLEED_GOLD
    Events.hp_changed.emit()
    Events.gold_changed.emit()
    Events.event_exited.emit()
