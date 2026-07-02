extends Control

@onready var enable_tutorial_panel: Panel = $EnableTutorialPanel


const RUN_SCENE := preload("res://scenes/run/run.tscn")

func _ready()  -> void:
    var main_menu_theme = preload("res://main_menu_theme_v2.ogg")
    SFXPlayer.play(main_menu_theme)
    get_tree().paused = false
    
func _on_new_run_pressed() -> void:
    enable_tutorial_panel.show()


func _on_cancel_tutorial_panel_pressed() -> void:
    enable_tutorial_panel.hide()


func _on_start_with_tutorial_pressed() -> void:
    Global.tutorial_on = true
    var new_run_sound = preload("res://success.mp3")
    SFXPlayer.stop()
    SFXPlayer.play(new_run_sound)
    await get_tree().create_timer(new_run_sound.get_length()).timeout
    get_tree().change_scene_to_packed(RUN_SCENE)


func _on_start_without_tutorial_pressed() -> void:
    Global.tutorial_on = false
    var new_run_sound = preload("res://success.mp3")
    SFXPlayer.stop()
    SFXPlayer.play(new_run_sound)
    await get_tree().create_timer(new_run_sound.get_length()).timeout
    get_tree().change_scene_to_packed(RUN_SCENE)
