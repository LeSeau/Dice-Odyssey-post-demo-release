extends Node

# VERIFICATION harness (2026-08-29) for one question only:
#   "Does rolling the RED die count as a rolled die for the per-roll relics/statuses,
#    the way every other type does?"
#
# Background: dice.gd::_apply_roll_result emits red_dice_rolled INSTEAD of dice_rolled for
# Red, while Global.fight_dice_rolled increments for EVERY roll including Red. That looks
# like Red rolls could silently skip Crown / Metronome / Sixth Gear / Hunting Bow. This
# harness measures it instead of guessing.
#
# Boots a REAL battle (debug_single_target_hitbox recipe) so the roll goes through the real
# dice.gd -> card_ui.gd -> relic path.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_red_roll_counts.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _relic_handler: RelicHandler
var _dice: Node
var _hand: Hand

# Counters fed by the probes
var _rolled_emits: Array = []
var _red_emits := 0


func check(check_name: String, ok: bool, detail := "") -> void:
	checks += 1
	var suffix := ("  [" + detail + "]") if detail != "" else ""
	if ok:
		print("PASS  ", check_name, suffix)
	else:
		fails += 1
		print("FAIL  ", check_name, suffix)


func _section(title: String) -> void:
	print("\n--- ", title, " ---")


func _on_dice_rolled(dice_type: String, value: int) -> void:
	_rolled_emits.append([dice_type, value])


func _on_red_dice_rolled() -> void:
	_red_emits += 1


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Global.tutorial_on = true
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	Events.dice_rolled.connect(_on_dice_rolled)
	Events.red_dice_rolled.connect(_on_red_dice_rolled)

	await _boot_battle()
	await _scenario_blue_baseline()
	await _scenario_red_socketed()
	await _scenario_red_two_sockets()

	print("\n==== RED ROLL COUNTING: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


func _boot_battle() -> void:
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)

	_relic_handler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(_relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	_battle.relics = _relic_handler
	_battle.battle_stats = load(FIGHT)
	_battle.act_tier = 1
	_relic_handler.add_relic(warrior.starting_relic)

	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 15.0)
	_dice = _battle.find_child("ActiveDice", true, false)
	_hand = _battle.find_child("Hand", true, false) as Hand
	check("battle booted", _dice != null and _hand != null)


# ---------------------------------------------------------------------------------------
# A. Baseline: a normal (Blue) roll emits exactly one dice_rolled and bumps the counter.
# ---------------------------------------------------------------------------------------
func _scenario_blue_baseline() -> void:
	_section("A. Blue roll baseline")
	_rolled_emits.clear()
	_red_emits = 0
	Global.dice_type = "blue"
	Global.blue_dice_current_amount = 3
	var before: int = Global.fight_dice_rolled
	_dice.roll_dice()
	await _settle(1.6)
	check("blue roll bumped fight_dice_rolled by 1",
			Global.fight_dice_rolled == before + 1,
			"%d -> %d" % [before, Global.fight_dice_rolled])
	check("blue roll emitted dice_rolled exactly once",
			_rolled_emits.size() == 1, str(_rolled_emits))
	check("blue roll emitted no red_dice_rolled", _red_emits == 0, str(_red_emits))


# ---------------------------------------------------------------------------------------
# B. The real question: a Red roll with ONE socketed card.
# ---------------------------------------------------------------------------------------
func _scenario_red_socketed() -> void:
	_section("B. Red roll, one socketed card")
	var card_ui := _first_socketable_card()
	if card_ui == null:
		check("found a socketable card in hand", false)
		return
	check("found a socketable card in hand", true, card_ui.card.id)

	Global.charged_card_instance_ids.clear()
	if not Global.charged_card_instance_ids.has(card_ui.card.instance_id):
		Global.charged_card_instance_ids.append(card_ui.card.instance_id)
	Events.card_charged.emit(card_ui)
	await _settle(0.6)

	_rolled_emits.clear()
	_red_emits = 0
	Global.dice_type = "red"
	Global.red_dice_current_amount = 3
	Global.roll_value = 0
	Global.roll_history = []
	var before: int = Global.fight_dice_rolled
	_dice.roll_dice()
	await _settle(2.2)

	check("red roll bumped fight_dice_rolled by 1",
			Global.fight_dice_rolled == before + 1,
			"%d -> %d" % [before, Global.fight_dice_rolled])
	check("red roll emitted red_dice_rolled once", _red_emits == 1, str(_red_emits))
	# THE question. If this is 0, Red rolls really do skip the per-roll relics.
	check("red roll ALSO emitted dice_rolled (counts as a roll)",
			_rolled_emits.size() >= 1, str(_rolled_emits))
	check("red roll emitted dice_rolled exactly once (no double-count)",
			_rolled_emits.size() == 1, str(_rolled_emits))


# ---------------------------------------------------------------------------------------
# C. Two socketed cards (Dual Cannon / red_socket_capacity 2): does ONE red roll emit
#    dice_rolled TWICE while fight_dice_rolled only moves by 1?
# ---------------------------------------------------------------------------------------
func _scenario_red_two_sockets() -> void:
	_section("C. Red roll, two socketed cards")
	Events.clear_socket.emit()
	await _settle(0.4)
	Global.charged_card_instance_ids.clear()
	Global.red_socket_capacity = 2

	var cards := _socketable_cards()
	if cards.size() < 2:
		check("found two socketable cards in hand", false, str(cards.size()))
		return
	check("found two socketable cards in hand", true)

	for c in cards.slice(0, 2):
		var cu := c as CardUI
		if not Global.charged_card_instance_ids.has(cu.card.instance_id):
			Global.charged_card_instance_ids.append(cu.card.instance_id)
		Events.card_charged.emit(cu)
		await _settle(0.5)

	check("two ids registered as charged",
			Global.charged_card_instance_ids.size() == 2,
			str(Global.charged_card_instance_ids.size()))

	_rolled_emits.clear()
	_red_emits = 0
	Global.dice_type = "red"
	Global.red_dice_current_amount = 3
	Global.roll_value = 0
	Global.roll_history = []
	var before: int = Global.fight_dice_rolled
	_dice.roll_dice()
	await _settle(2.2)

	check("two-socket red roll bumped fight_dice_rolled by exactly 1",
			Global.fight_dice_rolled == before + 1,
			"%d -> %d" % [before, Global.fight_dice_rolled])
	# If this FAILS with 2, one red roll fires every per-roll relic twice.
	check("two-socket red roll emitted dice_rolled exactly once",
			_rolled_emits.size() == 1, str(_rolled_emits))


# ---------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------
func _socketable_cards() -> Array:
	var out: Array = []
	for child in _hand.get_children():
		var cu := child as CardUI
		if cu == null or cu.card == null:
			continue
		if cu.card.can_play_without_dice:
			continue
		out.append(cu)
	return out


func _first_socketable_card() -> CardUI:
	var cards := _socketable_cards()
	return cards[0] as CardUI if not cards.is_empty() else null


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _await_until(predicate: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
