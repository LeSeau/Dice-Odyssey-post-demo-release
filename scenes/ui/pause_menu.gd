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
const DISCORD_URL := "https://discord.gg/fah8A2qQx2"

# Achievements list styling (rows are built in code in _populate_achievements - the
# global Cinzel theme is unreadable at body sizes, same reasoning as the toast).
const TROPHY_TEXTURE := preload("res://assets/images/achievement_trophy.png")
const ROW_BODY_FONT := preload("res://assets/static/Roboto_Condensed-SemiBold.ttf")
const ROW_BG_COLOR := Color(0.0509804, 0.113725, 0.121569)  # slider-track dark teal
const GOLD_COLOR := Color(1, 0.843137, 0)
const CREAM_COLOR := Color(0.92549, 0.890196, 0.815686)
const DIM_COLOR := Color(0.6, 0.57, 0.48)
const LOCKED_ICON_MODULATE := Color(0.32, 0.32, 0.36)

# Set true on the instance living in main_menu.tscn - there's no run to quit out of and
# nothing to "resume" into, so this hides the run-only bits (Quit to Main Menu, the
# "your progress is saved" note) and relabels Resume -> Close instead of duplicating
# the whole scene just to drop two buttons.
@export var is_standalone_settings: bool = false

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var master_pct: Label = %MasterPct
@onready var music_pct: Label = %MusicPct
@onready var sfx_pct: Label = %SfxPct
@onready var fullscreen_button: Button = %FullscreenButton
@onready var discord_button: Button = %DiscordButton
@onready var resume_button: Button = %ResumeButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var settings_panel: Panel = $Panel
@onready var confirm_quit_panel: Panel = $ConfirmQuitPanel
@onready var achievements_panel: Panel = $AchievementsPanel
@onready var achievements_button: Button = %AchievementsButton
@onready var ach_list: VBoxContainer = %AchList
@onready var ach_back_button: Button = %AchBackButton
@onready var confirm_quit_button: Button = %ConfirmQuitButton
@onready var cancel_quit_button: Button = %CancelQuitButton
@onready var title_label: Label = %Title
@onready var note_label: Label = %Note

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
    discord_button.pressed.connect(_on_discord_button_pressed)
    resume_button.pressed.connect(_on_resume_pressed)
    main_menu_button.pressed.connect(_on_main_menu_pressed)
    confirm_quit_button.pressed.connect(_on_confirm_quit_pressed)
    cancel_quit_button.pressed.connect(_on_cancel_quit_pressed)
    achievements_button.pressed.connect(_on_achievements_pressed)
    ach_back_button.pressed.connect(_on_ach_back_pressed)

    if is_standalone_settings:
        main_menu_button.hide()
        note_label.hide()
        title_label.text = "SETTINGS"
        resume_button.text = "Close"


# _unhandled_input (not _input) so overlays that legitimately own Esc - the card
# pile/deck views call set_input_as_handled() when open - win before this fires.
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        # Esc backs out one level at a time: confirm prompt / achievements -> settings -> resume.
        if visible and confirm_quit_panel.visible:
            _on_cancel_quit_pressed()
        elif visible and achievements_panel.visible:
            _on_ach_back_pressed()
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


func _on_discord_button_pressed() -> void:
    SFXPlayer.play(CLICK_SFX)
    OS.shell_open(DISCORD_URL)


func _on_resume_pressed() -> void:
    SFXPlayer.play(CLICK_SFX)
    close_menu()


func _show_settings_view() -> void:
    confirm_quit_panel.hide()
    achievements_panel.hide()
    settings_panel.show()


func _on_achievements_pressed() -> void:
    SFXPlayer.play(CLICK_SFX)
    _populate_achievements()
    settings_panel.hide()
    achievements_panel.show()


func _on_ach_back_pressed() -> void:
    SFXPlayer.play(CLICK_SFX)
    _show_settings_view()


# Rebuilt on every open so unlock states/progress are always current.
func _populate_achievements() -> void:
    for child in ach_list.get_children():
        child.queue_free()
    for def: Dictionary in AchievementManager.ACHIEVEMENTS:
        ach_list.add_child(_build_achievement_row(def))


func _build_achievement_row(def: Dictionary) -> PanelContainer:
    var unlocked: bool = AchievementManager.is_unlocked(def.id)

    var row := PanelContainer.new()
    var row_style := StyleBoxFlat.new()
    row_style.bg_color = ROW_BG_COLOR
    row_style.set_corner_radius_all(8)
    row_style.content_margin_left = 12
    row_style.content_margin_right = 14
    row_style.content_margin_top = 8
    row_style.content_margin_bottom = 8
    row.add_theme_stylebox_override("panel", row_style)

    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 12)
    row.add_child(hbox)

    var icon := TextureRect.new()
    icon.texture = TROPHY_TEXTURE
    icon.custom_minimum_size = Vector2(40, 40)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    icon.modulate = Color.WHITE if unlocked else LOCKED_ICON_MODULATE
    hbox.add_child(icon)

    var text_box := VBoxContainer.new()
    text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    text_box.add_theme_constant_override("separation", 1)
    hbox.add_child(text_box)
    text_box.add_child(_make_row_label(
        def.name, 18, GOLD_COLOR if unlocked else CREAM_COLOR))
    # Wrapped, not because anything wraps today (the longest current row needs 517px of the
    # 572px AchScroll gives it) but because AchScroll has horizontal scrolling disabled: a
    # future description a few words longer would silently clip off the right edge instead of
    # scrolling. Wrapping makes the row grow taller instead - the PanelContainer self-sizes.
    var desc_label := _make_row_label(def.desc, 13, DIM_COLOR)
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text_box.add_child(desc_label)

    var progress: Dictionary = AchievementManager.get_progress(def.id)
    var status_text := "Unlocked" if unlocked else "Locked"
    if not progress.is_empty():
        status_text = "%d / %d" % [progress.current, progress.target]
    var status := _make_row_label(status_text, 14, GOLD_COLOR if unlocked else DIM_COLOR)
    status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hbox.add_child(status)

    return row


func _make_row_label(text_value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    var settings := LabelSettings.new()
    settings.font = ROW_BODY_FONT
    settings.font_size = font_size
    settings.font_color = color
    settings.outline_size = 2
    settings.outline_color = Color(0, 0, 0, 0.5)
    label.label_settings = settings
    return label


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
