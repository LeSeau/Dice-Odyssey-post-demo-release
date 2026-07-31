extends Control

@onready var enable_tutorial_panel: Panel = $EnableTutorialPanel
@onready var load_run_button: Button = $LoadRun
@onready var load_run_confirm_panel: Panel = $LoadRunConfirmPanel
@onready var load_run_confirm_subtitle: Label = $LoadRunConfirmPanel/SubtitleLabel
@onready var load_run_stats: PanelContainer = $LoadRunConfirmPanel/RunStats
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
    # Version stamp - single source of truth is application/config/version in
    # project.godot; the .tscn text is only an editor placeholder.
    $VersionLabel.text = "v%s" % ProjectSettings.get_setting("application/config/version", "?")


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
    _show_load_confirm_panel()


func _populate_load_confirm_panel(data: Dictionary) -> void:
    var act: int = data.get("act", 1)
    var floors_climbed: int = data.get("map", {}).get("floors_climbed", 0)
    var floor_in_act: int = mini(floors_climbed + 1, MapGenerator.FLOORS)
    # Same act-offset numbering as the top bar's Floor label (act 2 continues the
    # count instead of restarting at 1).
    var global_floor: int = (act - 1) * MapGenerator.FLOORS + floor_in_act
    var total_dice := 0
    for amount: int in data.get("dice_max", {}).values():
        total_dice += amount

    load_run_confirm_subtitle.text = "Act %d  ·  Floor %d" % [act, global_floor]
    load_run_stats.build_rows([
        {"label": "Gold", "icon": "res://gold_icon_v2.png", "value": int(data.get("gold", 0))},
        {"label": "Health", "icon": "res://assets/images/heart.png", "text": "%d / %d" % [int(data.get("health", 0)), int(data.get("max_health", 0))]},
        {"label": "Cards in Deck", "icon": "res://card_cover_icon.png", "value": data.get("deck", []).size()},
        {"label": "Relics", "icon": "res://crown.png", "value": data.get("relics", []).size()},
        {"label": "Dice Owned", "icon": "res://assets/images/blue6.png", "value": total_dice},
    ])


const LOAD_PANEL_ENTRANCE_TIME := 0.3
const LOAD_PANEL_STATS_DELAY := 0.15

# Same settle-in pop + staggered scoreboard reveal beat as the end-of-run screens.
func _show_load_confirm_panel() -> void:
    load_run_confirm_panel.show()
    load_run_confirm_panel.pivot_offset = load_run_confirm_panel.size / 2.0
    load_run_confirm_panel.modulate.a = 0.0
    load_run_confirm_panel.scale = Vector2(0.94, 0.94)
    var tween := create_tween()
    tween.tween_property(load_run_confirm_panel, "modulate:a", 1.0, LOAD_PANEL_ENTRANCE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(load_run_confirm_panel, "scale", Vector2.ONE, LOAD_PANEL_ENTRANCE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_interval(LOAD_PANEL_STATS_DELAY)
    tween.tween_callback(load_run_stats.animate_in)


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


func _on_discord_button_pressed() -> void:
    OS.shell_open("https://discord.gg/fah8A2qQx2")


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
