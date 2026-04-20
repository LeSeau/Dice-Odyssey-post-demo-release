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


func show_screen(text: String, type: Type) -> void:
    if Global.game_over_state: 
        lost_panel.show()
        audio_player.stream = load("res://gameoversound.wav")
    else:
        audio_player.stream = load("res://victory_daiso.mp3")
    audio_player.play()
    label.text = text
    continue_button.visible = type == Type.WIN
    restart_button.visible = type == Type.LOSE
    show()
    get_tree().paused = true


func _on_join_discord_button_pressed() -> void:
    OS.shell_open("https://discord.gg/fah8A2qQx2")
