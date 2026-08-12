extends Node

# Regression harness for GOLEM DICE CARRY-OVER (internal type "even", 2026-08-12 rework).
#
# Golem is the one dice type whose turn refill is not `current = max + bonus`: whatever went
# unspent last turn is added on top. The rules being locked down here:
#   - leftovers carry into the next turn
#   - there is NO cap
#   - a NEGATIVE bonus (Depleted from Electrify, the Dicelord's Dice Theft) eats into the
#     carried dice, and the whole sum floors at 0 rather than going negative
#   - carry-over is per-FIGHT: banked dice must not appear in the next combat
#   - a SHOP PURCHASE between fights (shop.gd does `current += 1`) must NOT be read as a
#     leftover and handed out twice - this is why the carry has its own Global rather than
#     the refill just reading even_dice_current_amount
#   - no other dice type gains carry-over behaviour
#
# Boots a REAL battle.tscn through start_battle() (same recipe as debug_double_endturn.gd) so
# the actual dice_interface handlers are wired, then drives Events.player_turn_ended /
# player_turn_started directly - those are exactly the two signals the mechanic hangs off.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_golem_carryover.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle


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

	await _scenario_basic_carry()
	await _scenario_no_cap()
	await _scenario_depleted_eats_carry()
	await _scenario_floor_at_zero()
	await _scenario_shop_purchase_not_carry()
	await _scenario_other_types_unaffected()
	await _scenario_carry_is_fight_scoped()

	print("\n==== GOLEM CARRY-OVER: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


func _boot_battle() -> void:
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)

	var relic_handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	# Documented harness trap: an HBoxContainer with no Control ancestor collapses to zero size.
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	_battle.relics = relic_handler
	_battle.battle_stats = load(FIGHT)
	_battle.act_tier = 1
	# Documented harness trap: without the starting relic (Dice Bag) turn 1 hands out fewer
	# Blue dice than the real game, which has bitten a previous harness.
	relic_handler.add_relic(warrior.starting_relic)

	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 15.0)


# Runs one full turn boundary through the real signal pair.
func _turn_boundary() -> void:
	Events.player_turn_ended.emit()
	await get_tree().process_frame
	Events.player_turn_started.emit()
	await get_tree().process_frame


func _set_golem(maximum: int, bonus: int, current: int) -> void:
	Global.even_dice_max_amount = maximum
	Global.even_dice_bonus_amount = bonus
	Global.even_dice_current_amount = current


func _scenario_basic_carry() -> void:
	print("\n--- A: unspent Golem Dice carry into next turn ---")
	Global.golem_dice_carryover = 0
	_set_golem(2, 0, 1)  # 2 per turn, 1 left unspent
	await _turn_boundary()
	check("1 leftover + max 2 -> 3 next turn",
			Global.even_dice_current_amount == 3, "got %d" % Global.even_dice_current_amount)

	# Spending everything carries nothing.
	_set_golem(2, 0, 0)
	await _turn_boundary()
	check("0 leftover -> plain max refill (2)",
			Global.even_dice_current_amount == 2, "got %d" % Global.even_dice_current_amount)


func _scenario_no_cap() -> void:
	print("\n--- B: no cap on hoarding ---")
	_set_golem(2, 0, 0)
	await _turn_boundary()          # -> 2
	var seen: Array[int] = []
	for i in 3:
		# never spend: each turn should stack another full refill on top
		seen.append(Global.even_dice_current_amount)
		await _turn_boundary()
	check("3 unspent turns keep stacking (2,4,6 -> 8)",
			Global.even_dice_current_amount == 8,
			"progression %s then %d" % [str(seen), Global.even_dice_current_amount])


func _scenario_depleted_eats_carry() -> void:
	print("\n--- C: a negative bonus eats into the carry ---")
	Global.golem_dice_carryover = 0
	_set_golem(2, -1, 2)  # Depleted 1 (Electrify) / Dice Theft, with 2 banked
	await _turn_boundary()
	check("max 2, bonus -1, carry 2 -> 3",
			Global.even_dice_current_amount == 3, "got %d" % Global.even_dice_current_amount)
	check("bonus is consumed by the refill like every other type",
			Global.even_dice_bonus_amount == 0, "got %d" % Global.even_dice_bonus_amount)


func _scenario_floor_at_zero() -> void:
	print("\n--- D: the sum floors at 0, never negative ---")
	Global.golem_dice_carryover = 0
	_set_golem(1, -5, 1)
	await _turn_boundary()
	check("max 1, bonus -5, carry 1 -> 0 (not negative)",
			Global.even_dice_current_amount == 0, "got %d" % Global.even_dice_current_amount)


func _scenario_shop_purchase_not_carry() -> void:
	print("\n--- E: a shop purchase between fights is not a leftover ---")
	# Reproduces the real sequence: fight ends, player buys a Golem die in the shop (shop.gd
	# bumps BOTH max and current), next fight starts. The purchased die must be granted once.
	Global.golem_dice_carryover = 0
	_set_golem(0, 0, 0)
	Global.even_dice_max_amount += 1
	Global.even_dice_current_amount += 1   # exactly what shop.gd does
	Events.player_turn_started.emit()      # first turn of the next fight (no turn_ended before it)
	await get_tree().process_frame
	check("bought 1 Golem die -> 1 next turn, not 2",
			Global.even_dice_current_amount == 1, "got %d" % Global.even_dice_current_amount)


func _scenario_other_types_unaffected() -> void:
	print("\n--- F: no other dice type gains carry-over ---")
	Global.golem_dice_carryover = 0
	Global.odd_dice_max_amount = 2
	Global.odd_dice_current_amount = 2     # 2 unspent Ricochet dice
	Global.blue_dice_max_amount = 2
	Global.blue_dice_current_amount = 2
	Global.blue_dice_bonus_amount_fight = 0
	_set_golem(2, 0, 2)
	await _turn_boundary()
	check("Ricochet ('odd') still resets to max, no carry",
			Global.odd_dice_current_amount == 2, "got %d" % Global.odd_dice_current_amount)
	check("Blue still resets to max, no carry",
			Global.blue_dice_current_amount == 2, "got %d" % Global.blue_dice_current_amount)
	check("Golem in the same turn DID carry (control)",
			Global.even_dice_current_amount == 4, "got %d" % Global.even_dice_current_amount)


func _scenario_carry_is_fight_scoped() -> void:
	print("\n--- G: carry does not survive into the next fight ---")
	_set_golem(2, 0, 3)
	Events.player_turn_ended.emit()        # bank 3
	await get_tree().process_frame
	check("carry banked at turn end", Global.golem_dice_carryover == 3,
			"got %d" % Global.golem_dice_carryover)

	# A new combat starts: battle.gd::start_battle() clears the fight-scoped carry.
	_battle.battle_stats = load(FIGHT)
	_battle.start_battle()
	await _await_until(func() -> bool: return true, 1.0)
	check("start_battle() clears the banked carry", Global.golem_dice_carryover == 0,
			"got %d" % Global.golem_dice_carryover)


func _await_until(cond: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
