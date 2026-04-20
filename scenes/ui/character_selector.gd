extends Control

const WARRIOR_STATS := preload("res://characters/warrior/warrior.tres")

@onready var title: Label = $Title

var current_character : CharacterStats : set = set_current_character


func _ready() -> void: 
    set_current_character(WARRIOR_STATS)
    
func set_current_character(new_character: CharacterStats) -> void:
    current_character = new_character

func _on_start_button_pressed() -> void:
    print("start new run with" , current_character)
