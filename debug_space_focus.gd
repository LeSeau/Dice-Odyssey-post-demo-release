extends Node

# Throwaway probe: does Space end the turn after End Turn was clicked with the mouse
# (Godot keeps focus on the last clicked Button, and ui_accept presses a focused Button)?

var hands_drawn := 0
var turns_ended := 0
var rolls := 0

func _ready() -> void:
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	Events.player_turn_ended.connect(func() -> void: turns_ended += 1)
	Events.dice_rolled.connect(func(_t, _v) -> void: rolls += 1)
	var battle: Battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)
	var relic_handler: RelicHandler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(relic_handler)
	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	battle.char_stats = warrior.create_instance()
	battle.relics = relic_handler
	battle.battle_stats = load("res://battles/tier_1_crab_satyr.tres")
	battle.act_tier = 1
	battle.start_battle()
	await _until(func() -> bool: return hands_drawn >= 1, 20.0)
	for i in 30:
		await get_tree().process_frame

	var roll_button: Button = battle.find_child("ActiveDice", true, false).get_node("Button")
	var end_turn: Button = battle.find_child("EndTurnButton", true, false)
	print("[probe] roll focus_mode=", roll_button.focus_mode, " end_turn focus_mode=", end_turn.focus_mode)

	# A: click ROLL with the mouse, let it land, then press Space.
	await _click(roll_button)
	await get_tree().create_timer(1.2, false).timeout
	print("[probe] after mouse click on ROLL: rolls=", rolls, " roll has focus=", roll_button.has_focus())
	await _key(KEY_SPACE)
	await get_tree().create_timer(1.2, false).timeout
	print("[probe] after Space: rolls=", rolls)

	# B: click End Turn, wait for the next turn, then press Space.
	await _click(end_turn)
	var before := turns_ended
	await _until(func() -> bool: return hands_drawn >= 2, 30.0)
	for i in 30:
		await get_tree().process_frame
	print("[probe] next turn started. end_turn has focus=", end_turn.has_focus(), " disabled=", end_turn.disabled, " turns_ended=", turns_ended)
	await _key(KEY_SPACE)
	for i in 10:
		await get_tree().process_frame
	print("[probe] after Space at the start of the next turn: turns_ended=", turns_ended, " (was ", before, " after the click)")
	get_tree().quit()

func _click(b: Control) -> void:
	var vp_pos := b.get_global_transform_with_canvas() * (b.size / 2.0)
	var p := get_viewport().get_final_transform() * vp_pos
	print("[probe] click ", b.name, " viewport=", vp_pos, " window=", p)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame

func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame

func _until(cond: Callable, timeout_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
