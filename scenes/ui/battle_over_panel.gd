class_name BattleOverPanel
extends Panel

enum Type {WIN, LOSE}

@onready var label: Label = %Label
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var lost_panel: Panel = $LostPanel



func _ready() -> void:
    continue_button.pressed.connect(func(): Events.battle_won.emit())
    restart_button.pressed.connect(get_tree().reload_current_scene)
    Events.battle_over_screen_requested.connect(show_screen)
    Events.stop_battle_music.emit()


const WIN_AUTO_ADVANCE_DELAY := 0.7

func show_screen(text: String, type: Type) -> void:
    if type == Type.LOSE:
        lost_panel.show()
        audio_player.stream = load("res://gameoversound.wav")
        audio_player.play()
        label.text = text
        continue_button.visible = false
        restart_button.visible = true
        show()
        get_tree().paused = true
        return

    # Win: skip the manual "Continue" screen entirely (no need for a click, no
    # jingle) - just auto-advance straight to card rewards after a short beat.
    # A battle entered via run.gd's debug BattleButton skips the beat entirely
    # (Global.debug_battle_entry) so debug iteration isn't stuck waiting on it -
    # reset right away so it never leaks into the next real map-flow battle.
    if Global.debug_battle_entry:
        Global.debug_battle_entry = false
        Events.battle_won.emit()
        return

    if Global.tutorial_on:
        # TutorialDirector owns the win moment during the tutorial fight - it shows its
        # own victory step (T3.7) and emits battle_won itself once the player dismisses
        # it, so the reward screen can't cut the tutorial's closing beat short by racing
        # this auto-advance timer.
        return

    await get_tree().create_timer(WIN_AUTO_ADVANCE_DELAY).timeout
    Events.battle_won.emit()


func _on_join_discord_button_pressed() -> void:
    OS.shell_open("https://discord.gg/fah8A2qQx2")
