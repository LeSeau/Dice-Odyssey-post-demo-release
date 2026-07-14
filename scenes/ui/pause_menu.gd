class_name PauseMenu
extends CanvasLayer

# In-run pause/settings menu: gear button in the top bar, or Esc. Pauses the tree
# while open (same pattern as map consult in run.gd / battle_over_panel.gd); this
# layer is PROCESS_MODE_ALWAYS so it stays interactive. Remembers whether the tree
# was ALREADY paused when opened (map consult, game-over panel) and restores that
# state on close instead of blindly unpausing.

signal opened
signal closed

const CLICK_SFX := preload("res://sfx/219069__annabloom__click1.wav")
const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var master_pct: Label = %MasterPct
@onready var music_pct: Label = %MusicPct
@onready var sfx_pct: Label = %SfxPct
@onready var fullscreen_button: Button = %FullscreenButton
@onready var resume_button: Button = %ResumeButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var settings_panel: Panel = $Panel
@onready var confirm_quit_panel: Panel = $ConfirmQuitPanel
@onready var confirm_quit_button: Button = %ConfirmQuitButton
@onready var cancel_quit_button: Button = %CancelQuitButton

var _was_paused := false


func _ready() -> void:
    hide()
    master_slider.value_changed.connect(_on_volume_changed.bind("master_volume", master_pct))
    music_slider.value_changed.connect(_on_volume_changed.bind("music_volume", music_pct))
    sfx_slider.value_changed.connect(_on_volume_changed.bind("sfx_volume", sfx_pct))
    # Audible level check when a drag ends (value_changed alone would machine-gun it).
    master_slider.drag_ended.connect(_on_volume_drag_ended)
    music_slider.drag_ended.connect(_on_volume_drag_ended)
    sfx_slider.drag_ended.connect(_on_volume_drag_ended)
    fullscreen_button.pressed.connect(_on_fullscreen_pressed)
    resume_button.pressed.connect(_on_resume_pressed)
    main_menu_button.pressed.connect(_on_main_menu_pressed)
    confirm_quit_button.pressed.connect(_on_confirm_quit_pressed)
    cancel_quit_button.pressed.connect(_on_cancel_quit_pressed)


# _unhandled_input (not _input) so overlays that legitimately own Esc - the card
# pile/deck views call set_input_as_handled() when open - win before this fires.
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        # Esc backs out one level at a time: confirm prompt -> settings -> resume.
        if visible and confirm_quit_panel.visible:
            _on_cancel_quit_pressed()
        else:
            toggle()
        get_viewport().set_input_as_handled()


func toggle() -> void:
    if visible:
        close_menu()
    else:
        open_menu()


func open_menu() -> void:
    if visible:
        return
    _was_paused = get_tree().paused
    get_tree().paused = true
    _sync_ui()
    _show_settings_view()
    show()
    opened.emit()


func close_menu() -> void:
    if not visible:
        return
    get_tree().paused = _was_paused
    hide()
    _show_settings_view()
    closed.emit()


# set_value_no_signal: sliders only fire value_changed on real user input, so
# syncing here never re-triggers a save round-trip.
func _sync_ui() -> void:
    master_slider.set_value_no_signal(SettingsManager.get_value("master_volume"))
    music_slider.set_value_no_signal(SettingsManager.get_value("music_volume"))
    sfx_slider.set_value_no_signal(SettingsManager.get_value("sfx_volume"))
    _update_pct(master_pct, master_slider.value)
    _update_pct(music_pct, music_slider.value)
    _update_pct(sfx_pct, sfx_slider.value)
    _update_fullscreen_text()


func _on_volume_changed(value: float, key: String, pct_label: Label) -> void:
    SettingsManager.set_value(key, value)
    _update_pct(pct_label, value)


func _update_pct(pct_label: Label, value: float) -> void:
    pct_label.text = "%d%%" % roundi(value * 100)


func _on_volume_drag_ended(value_changed: bool) -> void:
    if value_changed:
        SFXPlayer.play(CLICK_SFX)


func _on_fullscreen_pressed() -> void:
    var on: bool = not SettingsManager.get_value("fullscreen")
    SettingsManager.set_value("fullscreen", on)
    _update_fullscreen_text()
    SFXPlayer.play(CLICK_SFX)


func _update_fullscreen_text() -> void:
    var on: bool = SettingsManager.get_value("fullscreen")
    fullscreen_button.text = "Fullscreen: On" if on else "Fullscreen: Off"


func _on_resume_pressed() -> void:
    SFXPlayer.play(CLICK_SFX)
    close_menu()


func _show_settings_view() -> void:
    confirm_quit_panel.hide()
    settings_panel.show()


# "Quit to Main Menu" asks for confirmation first - misclicking it mid-fight and
# instantly losing the room's progress would feel terrible, and the prompt is also
# where the "your progress is saved" reassurance lives.
func _on_main_menu_pressed() -> void:
    SFXPlayer.play(CLICK_SFX)
    settings_panel.hide()
    confirm_quit_panel.show()


func _on_cancel_quit_pressed() -> void:
    SFXPlayer.play(CLICK_SFX)
    _show_settings_view()


func _on_confirm_quit_pressed() -> void:
    get_tree().paused = false
    # Fight music runs through the MusicPlayer autoload, which survives the scene
    # change - without this it would keep looping under the main menu's own theme
    # (the menu plays its theme via SFXPlayer and never stops MusicPlayer itself).
    MusicPlayer.stop()
    SFXPlayer.stop()
    hide()
    get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
