extends Control

@onready var enable_tutorial_panel: Panel = $EnableTutorialPanel
@onready var load_run_button: Button = $LoadRun
@onready var load_run_confirm_panel: Panel = $LoadRunConfirmPanel
@onready var load_run_confirm_info: Label = $LoadRunConfirmPanel/InfoLabel
@onready var settings_button: TextureButton = %SettingsButton
@onready var settings_button_hover_glow: Panel = get_node("%SettingsButton/SettingsHoverGlow")
@onready var pause_menu: PauseMenu = %PauseMenu


const RUN_SCENE := preload("res://scenes/run/run.tscn")

func _ready()  -> void:
    var main_menu_theme = preload("res://main_menu_theme_v2.ogg")
    SFXPlayer.play(main_menu_theme)
    get_tree().paused = false
    # Load Run only shown when a run save actually exists. Both buttons share the
    # same ornate menu-button style (main_menu.tscn) - the background art itself
    # (main_menu_v4.png) no longer has any button painted into it.
    load_run_button.visible = SaveManager.has_save()


# Reads the save straight from disk instead of trusting has_save() alone (which
# only checks the file exists) - read_save() also rejects a corrupted or
# version-mismatched file, returning {}. That case falls through to run.gd's own
# fallback (_load_run starts a fresh run if the save is unusable), so skip the
# confirmation screen entirely and go straight to the load flow.
func _on_load_run_pressed() -> void:
    var data := SaveManager.read_save()
    if data.is_empty():
        _start_load_run()
        return
    _populate_load_confirm_panel(data)
    load_run_confirm_panel.show()


func _populate_load_confirm_panel(data: Dictionary) -> void:
    var floors_climbed: int = data.get("map", {}).get("floors_climbed", 0)
    var floor_num: int = mini(floors_climbed + 1, MapGenerator.FLOORS)
    var total_dice := 0
    for amount: int in data.get("dice_max", {}).values():
        total_dice += amount
    load_run_confirm_info.text = "Floor %d • Act %d\nGold: %d • HP: %d/%d\nDeck: %d cards • Relics: %d • Dice: %d" % [
        floor_num,
        data.get("act", 1),
        data.get("gold", 0),
        data.get("health", 0),
        data.get("max_health", 0),
        data.get("deck", []).size(),
        data.get("relics", []).size(),
        total_dice,
    ]


func _on_confirm_load_pressed() -> void:
    load_run_confirm_panel.hide()
    _start_load_run()


func _on_cancel_load_pressed() -> void:
    load_run_confirm_panel.hide()


func _start_load_run() -> void:
    # Consumed by run.gd::_late_init, which restores from SaveManager instead of
    # starting fresh. tutorial_on comes back from the save itself, so no tutorial
    # popup on this path.
    Global.load_run_requested = true
    var new_run_sound = preload("res://success.mp3")
    SFXPlayer.stop()
    SFXPlayer.play(new_run_sound)
    await get_tree().create_timer(new_run_sound.get_length()).timeout
    get_tree().change_scene_to_packed(RUN_SCENE)

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


func _on_settings_button_pressed() -> void:
    pause_menu.toggle()


# Same hover-glow treatment as the in-run gear button (run.gd::_on_pause_button_*).
func _on_settings_button_mouse_entered() -> void:
    settings_button.modulate = Color(1.18, 1.18, 1.18)
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(settings_button_hover_glow, "modulate:a", 1.0, 0.12)


func _on_settings_button_mouse_exited() -> void:
    settings_button.modulate = Color.WHITE
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(settings_button_hover_glow, "modulate:a", 0.0, 0.12)
