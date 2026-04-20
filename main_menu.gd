extends Control

@onready var new_run: Button = $VBoxContainer/NewRun

const RUN_SCENE := preload("res://scenes/run/run.tscn")

func _ready()  -> void:
    get_tree().paused = false

func _on_new_run_pressed() -> void:
    get_tree().change_scene_to_packed(RUN_SCENE)
