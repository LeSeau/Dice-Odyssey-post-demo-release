extends Node

# Regression harness for the RICOCHET DICE REROLL (internal type "odd", 2026-08-12 rework).
#
# Ricochet may reroll its result once per roll. The rules being locked down here:
#   - the SHOWN FACE always matches the banked value after a reroll. This is the 0.2.7
#     face/value mismatch guard: that bug came from a second animation path writing the face
#     with no ordering against the landing callback, so the reroll deliberately reuses the
#     normal roll path (_on_roll_landed kills _roll_flip_tween on its first line) instead of
#     getting a bespoke mini-animation. This harness exists mostly to keep it that way.
#   - Power is REPLACED, not stacked: the discarded roll leaves nothing behind
#   - roll_history keeps the same length, with the new value in the last slot
#   - once per roll, and the allowance does NOT refresh when the reroll itself lands
#   - no second die is consumed, and rerolling is still legal at 0 dice remaining
#   - a Scout/Focus/Lucky guarantee is spent, not refunded (a refund would force the same
#     face and make the reroll a no-op)
#   - a consumed Boost IS refunded and applies to whichever result is kept
#
# Runs with the REAL animation (testing_mode stays off) - the face check is meaningless
# otherwise, since testing_mode is exactly the path that skips the animation.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_ricochet_reroll.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
const FACE_TRIALS := 12          # roll+reroll cycles for the face/value assertion

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _dice: Node


func check(check_name: String, ok: bool, detail := "") -> void:
	checks += 1
	var suffix := ("  [" + detail + "]") if detail != "" else ""
	if ok:
		print("PASS  ", check_name, suffix)
	else:
		fails += 1
		print("FAIL  ", check_name, suffix)


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)

	await _boot_battle()
	await _select_ricochet()

	await _scenario_face_matches_value()
	await _scenario_power_replaced_not_stacked()
	await _scenario_history_length()
	await _scenario_once_per_roll()
	await _scenario_allowance_refreshes_on_new_roll()
	await _scenario_no_extra_die_spent()
	await _scenario_legal_at_zero_dice()
	await _scenario_guarantee_spent_not_refunded()
	await _scenario_boost_refunded()

	print("\n==== RICOCHET REROLL: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


func _boot_battle() -> void:
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)

	var relic_handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	_battle.relics = relic_handler
	_battle.battle_stats = load(FIGHT)
	_battle.act_tier = 1
	relic_handler.add_relic(warrior.starting_relic)

	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 15.0)
	_dice = _battle.find_child("ActiveDice", true, false)
	assert(_dice != null, "ActiveDice not found - harness cannot run")


# Give the player Ricochet dice and make the slot active, the same pair of steps
# dice_interface's slot click performs.
func _select_ricochet(amount := 40) -> void:
	Global.odd_dice_max_amount = amount
	Global.odd_dice_current_amount = amount
	Global.dice_type = "odd"
	Events.active_dice_changed.emit("odd")
	await get_tree().process_frame


func _roll_and_settle() -> void:
	_dice.roll_dice()
	await _await_until(func() -> bool: return not _dice._roll_in_progress, 12.0)


func _reroll_and_settle() -> void:
	_dice._on_ricochet_reroll_pressed()
	await _await_until(func() -> bool: return not _dice._roll_in_progress, 12.0)


# Clears the chain so the next scenario starts from a known state.
func _reset_chain() -> void:
	Events.dice_roll_reset.emit()
	await get_tree().process_frame
	await get_tree().process_frame


func _shown_face_path() -> String:
	var tex: Texture2D = _dice.dice_display.texture
	return "" if tex == null else tex.resource_path


func _scenario_face_matches_value() -> void:
	print("\n--- A: shown face always matches the banked value after a reroll (0.2.7 guard) ---")
	var mismatches := 0
	var samples: Array[String] = []
	for i in FACE_TRIALS:
		await _reset_chain()
		await _roll_and_settle()
		await _reroll_and_settle()
		var expected := "res://assets/images/odd%d.png" % Global.last_roll
		var shown := _shown_face_path()
		if shown != expected:
			mismatches += 1
			samples.append("value %d showed %s" % [Global.last_roll, shown])
	check("%d reroll cycles, shown face == rolled value" % FACE_TRIALS,
			mismatches == 0, "%d mismatch(es) %s" % [mismatches, str(samples)])


func _scenario_power_replaced_not_stacked() -> void:
	print("\n--- B: Power is replaced by the reroll, not added to ---")
	await _reset_chain()
	var before: int = Global.roll_value
	await _roll_and_settle()
	var first: int = Global.last_roll
	var after_first: int = Global.roll_value
	await _reroll_and_settle()
	var second: int = Global.last_roll
	check("roll_value == pre-roll + rerolled value only",
			Global.roll_value == before + second,
			"pre %d, first %d (->%d), rerolled %d, now %d"
					% [before, first, after_first, second, Global.roll_value])
	check("discarded roll is not also counted",
			Global.roll_value != before + first + second,
			"would have been %d" % (before + first + second))


func _scenario_history_length() -> void:
	print("\n--- C: roll history keeps its length, last entry is the kept value ---")
	await _reset_chain()
	await _roll_and_settle()
	var len_after_roll: int = Global.roll_history.size()
	await _reroll_and_settle()
	check("history length unchanged by the reroll",
			Global.roll_history.size() == len_after_roll,
			"%d -> %d" % [len_after_roll, Global.roll_history.size()])
	check("last history entry == kept value",
			Global.roll_history.back() == Global.last_roll,
			"history %s, last_roll %d" % [str(Global.roll_history), Global.last_roll])


func _scenario_once_per_roll() -> void:
	print("\n--- D: one reroll per roll, and the reroll's own landing does not refresh it ---")
	await _reset_chain()
	await _roll_and_settle()
	check("reroll available after a fresh roll", _dice._can_ricochet_reroll())
	# ⚠️ Assert on the BUTTON, not just the predicate. The predicate was true here while the
	# button stayed disabled for the whole turn, because _update_ricochet_button() ran before
	# _roll_in_progress was cleared - the harness passed and the feature was dead in game.
	# Anything the player clicks has to be checked in the state they actually see it.
	check("reroll BUTTON is enabled after a fresh roll", not _dice.ricochet_button.disabled)
	check("reroll SECTION is visible and undimmed",
			_dice.ricochet_section.visible and _dice.ricochet_section.modulate.a > 0.9,
			"visible=%s alpha=%.2f" % [_dice.ricochet_section.visible,
					_dice.ricochet_section.modulate.a])
	await _reroll_and_settle()
	check("reroll NOT available again after rerolling", not _dice._can_ricochet_reroll(),
			"rerolls_used=%d" % _dice.ricochet_rerolls_used)
	check("reroll BUTTON is disabled again after rerolling", _dice.ricochet_button.disabled)

	# Pressing anyway must be inert, not a second reroll.
	var value_before: int = Global.roll_value
	_dice._on_ricochet_reroll_pressed()
	await get_tree().process_frame
	check("pressing a spent reroll changes nothing",
			Global.roll_value == value_before and _dice.ricochet_rerolls_used == 1,
			"value %d->%d, used %d" % [value_before, Global.roll_value,
					_dice.ricochet_rerolls_used])


func _scenario_allowance_refreshes_on_new_roll() -> void:
	print("\n--- E: a NEW roll refreshes the allowance ---")
	await _reset_chain()
	await _roll_and_settle()
	await _reroll_and_settle()
	check("spent before the new roll", not _dice._can_ricochet_reroll())
	await _roll_and_settle()          # a genuinely new die
	check("available again after rolling another die", _dice._can_ricochet_reroll(),
			"rerolls_used=%d" % _dice.ricochet_rerolls_used)
	check("reroll BUTTON re-enabled after rolling another die",
			not _dice.ricochet_button.disabled)


func _scenario_no_extra_die_spent() -> void:
	print("\n--- F: a reroll does not consume a second die ---")
	await _reset_chain()
	await _select_ricochet(5)
	var before: int = Global.odd_dice_current_amount
	await _roll_and_settle()
	var after_roll: int = Global.odd_dice_current_amount
	await _reroll_and_settle()
	check("roll spends exactly 1", after_roll == before - 1,
			"%d -> %d" % [before, after_roll])
	check("reroll spends 0", Global.odd_dice_current_amount == after_roll,
			"%d -> %d" % [after_roll, Global.odd_dice_current_amount])


func _scenario_legal_at_zero_dice() -> void:
	print("\n--- G: rerolling your LAST die is still legal ---")
	await _reset_chain()
	await _select_ricochet(1)
	await _roll_and_settle()
	check("no dice left after spending the last one",
			Global.odd_dice_current_amount == 0,
			"got %d" % Global.odd_dice_current_amount)
	check("reroll still offered at 0 remaining", _dice._can_ricochet_reroll())
	var before: int = Global.roll_value
	await _reroll_and_settle()
	check("reroll actually resolved at 0 remaining",
			Global.roll_history.size() == 1 and Global.roll_value == Global.last_roll,
			"value %d -> %d, history %s"
					% [before, Global.roll_value, str(Global.roll_history)])
	await _select_ricochet(40)


func _scenario_guarantee_spent_not_refunded() -> void:
	print("\n--- H: a Scout/Lucky guarantee is spent, not refunded ---")
	await _reset_chain()
	Global.next_guaranteed_roll = 7          # top face of Ricochet
	await _roll_and_settle()
	check("guaranteed roll landed on 7", Global.last_roll == 7,
			"got %d" % Global.last_roll)
	check("guarantee consumed by the first roll", Global.next_guaranteed_roll == -1,
			"got %d" % Global.next_guaranteed_roll)
	await _reroll_and_settle()
	check("guarantee not refunded by the reroll", Global.next_guaranteed_roll == -1,
			"got %d" % Global.next_guaranteed_roll)


func _scenario_boost_refunded() -> void:
	print("\n--- I: a Boost consumed by the discarded roll comes back and applies once ---")
	await _reset_chain()
	Global.next_roll_modifier = 3
	await _roll_and_settle()
	var first_total: int = Global.roll_value
	check("boost applied to the first roll", first_total == Global.last_roll + 3,
			"value %d, roll %d" % [first_total, Global.last_roll])
	check("boost consumed", Global.next_roll_modifier == 0,
			"got %d" % Global.next_roll_modifier)
	await _reroll_and_settle()
	check("boost re-applied to the kept roll exactly once",
			Global.roll_value == Global.last_roll + 3,
			"value %d, roll %d" % [Global.roll_value, Global.last_roll])
	check("boost not left pending after the reroll", Global.next_roll_modifier == 0,
			"got %d" % Global.next_roll_modifier)


func _await_until(cond: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
