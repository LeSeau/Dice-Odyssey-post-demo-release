extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const UPGRADE_COST := 30

@onready var sharpen_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Sharpen

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Paid upfront on click, win or lose - the shrine sells you the OPPORTUNITY to pick
# a card to upgrade, not a guaranteed outcome (same principle as a shop reroll).
# card_pile_view.gd's confirm handler hardcodes Events.campfire_exited on success,
# which run.gd routes to the same _show_map() as event_exited - so a completed
# upgrade closes this screen correctly on its own. If the player backs out instead
# (Back/Cancel in that view) nothing auto-closes - Skip is left visible/clickable so
# there's still a way out (it'll also hand out its gold in that edge case on top of
# the sunk upgrade cost, which is a minor quirk, not an exploit - it's still a net loss).
func _on_sharpen_pressed() -> void:
    if Global.gold < UPGRADE_COST:
        return
    Global.gold -= UPGRADE_COST
    Events.gold_changed.emit()
    sharpen_button.hide()
    Events.open_deck_view_for_upgrade.emit()


func _on_leave_pressed() -> void:
    Events.event_exited.emit()
