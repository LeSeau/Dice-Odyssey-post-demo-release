extends Control

@onready var quit: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit
@onready var continue_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/ContinueButton
@onready var remove_card_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/RemoveCardButton


const CARD_REWARD_SCENE := preload("res://scenes/ui/card_rewards.tscn")

var character_stats: CharacterStats
var run_stats: RunStats

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _ready():
    print("ok")
    # Connect the button's pressed signal to the _on_pressed function


func _on_gain_card_pressed() -> void:
    Events.show_reward.emit()


func _on_quit_pressed() -> void:
    Events.event_exited.emit()


func _on_remove_card_button_pressed() -> void:
    print("removing")
    character_stats.health-=10
    Events.hp_changed.emit()
    Events.open_deck_view.emit()
    continue_button.show()
    quit.hide()
    remove_card_button.hide()
    
    


func _on_continue_button_pressed() -> void:
    Events.event_exited.emit()
