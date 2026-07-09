extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const GOLD_REWARD := 40

@onready var sell_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Sell

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Same pattern as event_hungry_altar.gd - the gold only pays out once a card has
# actually been sacrificed, connected one-shot only at the moment of commitment.
# Ignore stays visible the whole time as the escape hatch if the deck view gets
# backed out of without removing anything.
func _on_sell_pressed() -> void:
    sell_button.hide()
    Events.card_removed.connect(_on_card_sold, CONNECT_ONE_SHOT)
    Events.open_deck_view.emit()


func _on_card_sold(_card) -> void:
    Global.gold += GOLD_REWARD
    Events.gold_changed.emit()
    Events.event_exited.emit()


func _on_ignore_pressed() -> void:
    Events.event_exited.emit()
