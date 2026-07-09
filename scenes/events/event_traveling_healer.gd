extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const PAID_COST := 30
const PAID_HEAL := 30
const FREE_HEAL := 12

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _on_pay_pressed() -> void:
    if Global.gold < PAID_COST:
        return
    Global.gold -= PAID_COST
    Events.gold_changed.emit()
    character_stats.health += PAID_HEAL
    Events.hp_changed.emit()
    Events.event_exited.emit()


func _on_free_pressed() -> void:
    character_stats.health += FREE_HEAL
    Events.hp_changed.emit()
    Events.event_exited.emit()
