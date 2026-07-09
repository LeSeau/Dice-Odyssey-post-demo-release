extends Control

var character_stats: CharacterStats
var run_stats: RunStats

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Both paths are free and neither button is ever hidden - backing out of either
# the removal or upgrade flow (their own Back/Cancel button) just leaves you
# back here, free to try the other one or the same one again. The is_connected()
# guard matters because of that: clicking Forget, cancelling, then clicking
# Forget again would otherwise try to connect the same Callable twice, which
# Godot errors on.
func _on_forget_pressed() -> void:
    if not Events.card_removed.is_connected(_on_card_removed):
        Events.card_removed.connect(_on_card_removed, CONNECT_ONE_SHOT)
    Events.open_deck_view.emit()


func _on_card_removed(_card) -> void:
    Events.event_exited.emit()


# card_pile_view.gd's confirm handler emits Events.campfire_exited on a
# completed upgrade, which run.gd routes to the same _show_map() as
# event_exited - nothing extra needed here to close this screen on success.
func _on_refine_pressed() -> void:
    Events.open_deck_view_for_upgrade.emit()
