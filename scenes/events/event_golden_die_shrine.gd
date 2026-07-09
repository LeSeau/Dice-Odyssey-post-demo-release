extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const HEAL_AMOUNT := 15

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# card_pile_view.gd's confirm handler emits Events.campfire_exited on a
# completed upgrade, which run.gd routes to the same _show_map() as
# event_exited - nothing extra needed here to close this screen on success.
func _on_sharpen_pressed() -> void:
    Events.open_deck_view_for_upgrade.emit()


func _on_soothe_pressed() -> void:
    character_stats.health += HEAL_AMOUNT
    Events.hp_changed.emit()
    Events.event_exited.emit()
