extends Control

@onready var gain_card: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/GainCard
@onready var quit: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit
const CARD_REWARD_SCENE := preload("res://scenes/ui/card_rewards.tscn")

func _ready():
    print("ok")
    # Connect the button's pressed signal to the _on_pressed function


func _on_gain_card_pressed() -> void:
    Events.show_reward.emit()


func _on_quit_pressed() -> void:
    Events.event_exited.emit()
