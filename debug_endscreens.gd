# Debug harness (not shipped): renders the three end-of-run screens with fake stats
# and saves PNGs to debug_endscreens_out/. Run with:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_endscreens.tscn \
#     --rendering-driver opengl3 --position 2000,2000
extends Node

const LOSE_SCENE := "res://scenes/ui/battle_over_panel.tscn"
const REWARD_SCENE := "res://scenes/battle_reward/battle_reward.tscn"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://debug_endscreens_out"))

	Global.run_stat_highest_floor = 23
	Global.run_stat_dice_rolled = 347
	Global.run_stat_power_generated = 1482
	Global.run_stat_biggest_hit = 44
	Global.run_stat_damage_taken = 173
	Global.run_stat_cards_played = 156
	Global.run_stat_enemies_slain = 38

	await _capture_rewards()
	await _capture_lose()
	await _capture_win(1, "win_act1.png")
	await _capture_win(2, "win_final.png")
	await _capture_load_confirm()
	await _capture_main_menu()
	get_tree().quit()


func _capture_main_menu() -> void:
	var vp := _make_viewport()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	vp.add_child(menu)
	await _wait_frames(20)
	_save(vp, "main_menu.png")
	vp.queue_free()
	await _wait_frames(2)


# Normal post-fight rewards screen (no boss panel) with the usual three rows.
func _capture_rewards() -> void:
	Global.is_final_boss_fight = false
	var vp := _make_viewport()
	var reward: Control = load(REWARD_SCENE).instantiate()
	vp.add_child(reward)
	reward.add_gold_reward(21)
	reward.add_card_reward()
	await _wait_frames(170)
	_save(vp, "rewards.png")
	vp.queue_free()
	await _wait_frames(2)

	# Also render the 3-row elite case (gold + card + relic) to confirm the
	# content-sized card grows correctly.
	var vp3 := _make_viewport()
	var reward3: Control = load(REWARD_SCENE).instantiate()
	vp3.add_child(reward3)
	reward3.add_gold_reward(64)
	reward3.add_card_reward()
	reward3.add_relic_reward(load("res://relics/cartographers_quill.tres"))
	await _wait_frames(170)
	_save(vp3, "rewards_elite.png")
	vp3.queue_free()
	await _wait_frames(2)


func _capture_load_confirm() -> void:
	var vp := _make_viewport()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	vp.add_child(menu)
	await _wait_frames(2)
	var fake_deck: Array = []
	fake_deck.resize(18)
	menu._populate_load_confirm_panel({
		"act": 2,
		"map": {"floors_climbed": 4},
		"gold": 231,
		"health": 47,
		"max_health": 72,
		"deck": fake_deck,
		"relics": ["a", "b", "c", "d"],
		"dice_max": {"blue": 3, "red": 1, "magma": 1},
	})
	menu._show_load_confirm_panel()
	await _wait_frames(150)
	_save(vp, "load_confirm.png")
	vp.queue_free()
	await _wait_frames(2)


func _capture_lose() -> void:
	var vp := _make_viewport()
	var panel: Panel = load(LOSE_SCENE).instantiate()
	vp.add_child(panel)
	await _wait_frames(2)
	panel.show()
	# Drive the entrance directly instead of show_screen() - that would pause the
	# whole tree, freezing the later battle_reward captures' tweens.
	panel._play_lost_entrance()
	await _wait_frames(170)
	_save(vp, "lose.png")
	vp.queue_free()
	await _wait_frames(2)


func _capture_win(act: int, out_name: String) -> void:
	Global.is_final_boss_fight = true
	Global.current_act = act
	var vp := _make_viewport()
	var reward: Control = load(REWARD_SCENE).instantiate()
	vp.add_child(reward)
	await _wait_frames(170)
	_save(vp, out_name)
	vp.queue_free()
	await _wait_frames(2)


func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(vp: SubViewport, out_name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png("res://debug_endscreens_out/" + out_name)
	print("[endscreens] saved ", out_name)
