extends Control
@onready var leave_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/LeaveButton
@onready var accept_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/AcceptButton


var character_stats: CharacterStats
var run_stats: RunStats

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats

func _on_accept_button_pressed() -> void:
    Global.gold +=40
    Events.gold_changed.emit()
    Events.event_exited.emit()




func _on_leave_button_pressed() -> void:
    Events.event_exited.emit()


func _on_more_money_button_pressed() -> void:
    character_stats.health-=16
    Global.gold +=100
    Events.hp_changed.emit()
    Events.gold_changed.emit()
    Events.event_exited.emit()
