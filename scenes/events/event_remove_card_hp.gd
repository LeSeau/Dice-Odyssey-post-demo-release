extends Control

@export var treasure_relic_pool: RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

@onready var quit: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit
@onready var give_blood_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/GiveBloodButton

const HP_COST := 8

var character_stats: CharacterStats
var run_stats: RunStats

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _on_quit_pressed() -> void:
    Events.event_exited.emit()


# Oswald wants blood, not cards - trades a Relic for HP instead of removing a
# card from the deck (the old mechanic didn't match the vampire flavor text at
# all). Redirects straight to the reward screen like hollow_idol.gd/
# fickle_broker.gd, same "pay-first, then hand off" pattern.
func _on_give_blood_button_pressed() -> void:
    var relic := treasure_relic_pool.get_random_relic(char_stats, relic_handler)
    if not relic:
        Events.event_exited.emit()
        return
    character_stats.health -= HP_COST
    Events.hp_changed.emit()
    Events.show_reward_with_relic.emit(relic)
