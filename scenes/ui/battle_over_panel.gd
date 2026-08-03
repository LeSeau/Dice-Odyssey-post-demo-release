class_name BattleOverPanel
extends Panel

enum Type {WIN, LOSE}

const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const DISCORD_URL := "https://discord.gg/fah8A2qQx2"

const WIN_AUTO_ADVANCE_DELAY := 0.7
const PANEL_ENTRANCE_TIME := 0.34
const STATS_REVEAL_DELAY := 0.25

@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var lost_panel: Panel = $LostPanel
@onready var run_stats_panel: PanelContainer = $LostPanel/RunStats
@onready var try_again_button: Button = $LostPanel/TryAgainButton
@onready var main_menu_button: Button = $LostPanel/MainMenuButton


func _ready() -> void:
	try_again_button.pressed.connect(_on_try_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	Events.battle_over_screen_requested.connect(show_screen)
	Events.stop_battle_music.emit()


func show_screen(_text: String, type: Type) -> void:
	if type == Type.LOSE:
		# Hide the run HUD chrome (relic bar + Discord pin) that floats above this panel;
		# both exits (Try Again / Main Menu) rebuild the scene, so no restore is needed.
		Events.end_screen_hud_visibility.emit(false)
		audio_player.stream = load("res://gameoversound.wav")
		audio_player.play()
		show()
		_play_lost_entrance()
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


# Settle-in pop for the Game Over panel, then hand off to the stats scoreboard's own
# staggered reveal. This node is PROCESS_MODE_ALWAYS, so these tweens (and the stats
# panel's, bound to its children) keep running on the paused tree.
func _play_lost_entrance() -> void:
	lost_panel.show()
	lost_panel.pivot_offset = lost_panel.size / 2.0
	lost_panel.modulate.a = 0.0
	lost_panel.scale = Vector2(0.93, 0.93)
	var tween := create_tween()
	tween.tween_property(lost_panel, "modulate:a", 1.0, PANEL_ENTRANCE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lost_panel, "scale", Vector2.ONE, PANEL_ENTRANCE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(STATS_REVEAL_DELAY)
	tween.tween_callback(run_stats_panel.animate_in)


func _on_try_again_pressed() -> void:
	SFXPlayer.play(Global.sfx_click)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	# Same recipe as the pause menu's quit: the music autoloads survive the scene
	# change, so without these the run's music would keep looping under the menu.
	MusicPlayer.stop()
	SFXPlayer.stop()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_join_discord_button_pressed() -> void:
	OS.shell_open(DISCORD_URL)
