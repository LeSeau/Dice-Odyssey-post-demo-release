extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const HEAL_AMOUNT := 15

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Same is_connected() guard as event_twin_shrines.gd - Lighten Load is never
# hidden, so it needs to tolerate being clicked, cancelled, and clicked again.
func _on_lighten_load_pressed() -> void:
    if not Events.card_removed.is_connected(_on_card_removed):
        Events.card_removed.connect(_on_card_removed, CONNECT_ONE_SHOT)
    Events.open_deck_view.emit()


func _on_card_removed(_card) -> void:
    Events.event_exited.emit()


func _on_mend_wounds_pressed() -> void:
    character_stats.health += HEAL_AMOUNT
    Events.hp_changed.emit()
    Events.event_exited.emit()
