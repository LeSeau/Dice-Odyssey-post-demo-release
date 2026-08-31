extends Node

# Verification harness for the 2026-08-24 RELIC REWORK (Julien's balance pass).
#
#   6 cuts   diplomats_seal, wayfinder_compass, spyglass, fuel-o-meter, crown, prismatic_lens
#
# Amended 2026-08-31 (Julien's second relic pass): Spyglass is UNCUT and back in both pools
# with a new effect, Needle Die is cut in its place, and Giant's Signet goes back to paying
# Strength. Pools are 43 (42 - needle_die + spyglass + gamblers_fan).
#   11 edits war_horn, fuel_gauge, sixth_gear, pilot_light, metronome, hunting_bow,
#            hagglers_loupe, flywheel, echo_chamber, giants_signet, blood_chalice
#
# A. Data - pools shrank to 42 and still match each other, the cuts are gone from BOTH,
#    rarities landed, and every surviving relic still loads.
# B. Behaviour - boots a REAL battle.tscn and drives each reworked relic through the actual
#    signal it hangs off. Each scenario removes its relic afterwards, so the ones that write
#    Global state (Haggler's Loupe) also prove deactivate_relic cleans up.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_relic_rework.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
const CUTS := ["diplomats_seal", "wayfinder_compass", "fuel-o-meter", "crown",
		"prismatic_lens", "needle_die"]
const EXPECTED_POOL := 43

var checks := 0
var fails := 0
var hands_drawn := 0
var cards_drawn := 0
var _battle: Battle
var _relic_handler: RelicHandler
var _player: Player


func check(n: String, ok: bool, detail := "") -> void:
	checks += 1
	var suffix := ("  [" + detail + "]") if detail != "" else ""
	if ok:
		print("  PASS  ", n, suffix)
	else:
		fails += 1
		print("  FAIL  ", n, suffix)


func _section(t: String) -> void:
	print("\n--- ", t, " ---")


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	Events.draw_card.connect(func(n: int) -> void: cards_drawn += n)

	_section("A. POOLS + DATA")
	_check_pools()
	_check_rarity_and_text()

	_section("B. BEHAVIOUR")
	await _boot_battle()
	await _scenario_start_of_fight()
	await _scenario_refuel()
	# Order matters: the Metronome scenario ends by dropping a 20-damage AoE, which leaves
	# the low-HP Satyrs on 0. The per-roll relics measure single-target damage, so they run
	# on healthy bodies FIRST - otherwise Hunting Bow's random target can be a corpse and
	# the test reads 0 damage while the relic is working fine.
	await _scenario_misc()
	await _scenario_counters()

	print("\n==== RELIC REWORK: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ A. data
func _ids(pool_path: String) -> Array:
	var pool := load(pool_path) as RelicPool
	var out := []
	for r: Relic in pool.pool:
		if r != null:
			out.append(r.id)
	return out


func _check_pools() -> void:
	var t := _ids("res://treasure_relic_pool.tres")
	var s := _ids("res://shop_relic_pool.tres")
	check("treasure pool loads with %d relics" % EXPECTED_POOL, t.size() == EXPECTED_POOL, str(t.size()))
	check("shop pool loads with %d relics" % EXPECTED_POOL, s.size() == EXPECTED_POOL, str(s.size()))
	t.sort()
	s.sort()
	check("both pools carry the SAME roster (shop_only is the filter)", t == s)
	check("no null entries survived the cut", not t.has(null))
	check("no duplicate ids", t.size() == _unique(t).size())
	for c in CUTS:
		# fuel-o-meter's id is "fuel_o_meter"-ish; compare on the file stem via the pool text.
		check("CUT %s absent from treasure pool" % c, not _pool_text("res://treasure_relic_pool.tres").contains("relics/%s.tres" % c))
		check("CUT %s absent from shop pool" % c, not _pool_text("res://shop_relic_pool.tres").contains("relics/%s.tres" % c))
		check("CUT %s file still on disk (convention)" % c, ResourceLoader.exists("res://relics/%s.tres" % c))


func _pool_text(p: String) -> String:
	return FileAccess.get_file_as_string(p)


func _unique(a: Array) -> Array:
	var seen := {}
	for x in a:
		seen[x] = true
	return seen.keys()


func _check_rarity_and_text() -> void:
	var want := {
		"fuel_gauge": Relic.RarityTier.UNCOMMON,
		"metronome": Relic.RarityTier.RARE,
		"blood_chalice": Relic.RarityTier.RARE,
		"flywheel": Relic.RarityTier.COMMON,
		# 2026-08-24, second pass: 6 Uncommons demoted to Common - not new payouts, just
		# offered more often. rarity_tier=0 is the enum default, so the .tres files carry
		# NO line at all rather than an explicit 0 (see relic.gd's own comment on this).
		"hunting_bow": Relic.RarityTier.COMMON,
		"house_money": Relic.RarityTier.COMMON,
		"mortar_trowel": Relic.RarityTier.COMMON,
		"runic_bones": Relic.RarityTier.COMMON,
		"thorned_plate": Relic.RarityTier.COMMON,
		"worms_eye_lens": Relic.RarityTier.COMMON,
	}
	for rid in want:
		var r := load("res://relics/%s.tres" % rid) as Relic
		check("%s rarity" % rid, r.rarity_tier == want[rid], "got %d want %d" % [r.rarity_tier, want[rid]])
	# Tooltips must state the new numbers - a stale tooltip is a lie the player acts on.
	var texts := {
		"war_horn": "Red Dice",
		"fuel_gauge": "20 Power",
		"sixth_gear": "6 Power",   # retuned 2026-08-28: every 8 dice for 6 Power
		"pilot_light": "3 Power",
		"metronome": "20 damage",
		"hunting_bow": "3 damage",
		"hagglers_loupe": "10%",
		"flywheel": "draw 2 cards",
		"echo_chamber": "Once per turn",
		"giants_signet": "2 Strength",
	}
	for rid in texts:
		var r := load("res://relics/%s.tres" % rid) as Relic
		check("%s tooltip says '%s'" % [rid, texts[rid]], r.tooltip.contains(texts[rid]), r.tooltip)


# ------------------------------------------------------------------ B. boot
func _boot_battle() -> void:
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)
	_relic_handler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(_relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	_battle.battle_stats = load(FIGHT)
	_battle.relics = _relic_handler
	_relic_handler.add_relic(warrior.starting_relic)

	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 15.0)
	_player = get_tree().get_first_node_in_group("player") as Player
	check("battle booted", _player != null)


func _add(rid: String) -> Relic:
	var relic := load("res://relics/%s.tres" % rid) as Relic
	_relic_handler.add_relic(relic)
	return relic


func _remove(rid: String) -> void:
	for relic_ui: RelicUI in _relic_handler.relics.get_children():
		if relic_ui.relic and relic_ui.relic.id == rid:
			relic_ui.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
			return


func _block() -> int:
	return _player.stats.block


func _strength() -> int:
	var total := 0
	for status: Status in _player.status_handler._get_all_statuses():
		if status.id == "strength":
			total += status.stacks
	return total


func _enemy_hp() -> int:
	var total := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		total += e.stats.health
	return total


# Mirrors global.gd::report_dice_roll: BOTH counters move before the signal, which is what
# the fight-scoped relics (Sixth Gear, Metronome) read.
func _fake_roll(dice_type: String, value: int) -> void:
	Global.dice_type = dice_type
	Global.last_roll = value
	Global.dice_amount_rolled_this_turn += 1
	Global.fight_dice_rolled += 1
	Events.dice_rolled.emit(dice_type, value)


# ------------------------------------------------------------------ B. scenarios
func _scenario_start_of_fight() -> void:
	_section("start-of-fight relics")

	Global.red_dice_bonus_amount = 0
	var wh := _add("war_horn")
	for relic_ui: RelicUI in _relic_handler.relics.get_children():
		if relic_ui.relic == wh:
			wh.activate_relic(relic_ui)
	check("War Horn: grants a bonus Red Dice", Global.red_dice_bonus_amount == 1,
			str(Global.red_dice_bonus_amount))
	await _remove("war_horn")

	Global.starting_power_next_turn = 0
	_add("pilot_light")
	Events.battle_started.emit()
	check("Pilot Light: 3 Power banked for the fight start",
			Global.starting_power_next_turn == 3, str(Global.starting_power_next_turn))
	Events.player_turn_ended.emit()
	check("Pilot Light: does NOT re-bank each turn (fight-start only)",
			Global.starting_power_next_turn == 3, str(Global.starting_power_next_turn))
	await _remove("pilot_light")


func _scenario_refuel() -> void:
	_section("refuel relics")

	Global.refueled_power_this_fight = 0
	_add("fuel_gauge")
	var s0 := _strength()
	Events.refuel_happened.emit(7)
	check("Fuel Gauge: 7 alone does not pay", _strength() == s0, str(_strength() - s0))
	Events.refuel_happened.emit(7)
	check("Fuel Gauge: 14 alone does not pay", _strength() == s0)
	Events.refuel_happened.emit(7)
	check("Fuel Gauge: 21 total pays 3 Strength", _strength() == s0 + 3, str(_strength() - s0))
	Events.refuel_happened.emit(9)
	check("Fuel Gauge: does not pay twice in one fight", _strength() == s0 + 3, str(_strength() - s0))
	await _remove("fuel_gauge")

	cards_drawn = 0
	_add("flywheel")
	Events.refuel_happened.emit(5)
	check("Flywheel: refuel draws 2 cards", cards_drawn == 2, str(cards_drawn))
	await _remove("flywheel")


func _scenario_counters() -> void:
	_section("fight-scoped counters")

	Global.fight_dice_rolled = 0
	Global.roll_value = 0
	_add("sixth_gear")
	for i in 7:
		_fake_roll("blue", 1)
	var before: int = Global.roll_value
	check("Sixth Gear: silent for the first 7 dice", true, "power %d" % before)
	_fake_roll("blue", 1)
	check("Sixth Gear: 8th die of the FIGHT grants 6 Power (retuned 2026-08-28)",
			Global.roll_value == before + 6, "delta %d" % (Global.roll_value - before))
	# The old version was per-turn; a turn boundary must NOT reset the count now.
	Global.dice_amount_rolled_this_turn = 0
	for i in 7:
		_fake_roll("blue", 1)
	before = Global.roll_value
	_fake_roll("blue", 1)
	check("Sixth Gear: 16th die pays even across a turn boundary",
			Global.roll_value == before + 6, "delta %d" % (Global.roll_value - before))
	await _remove("sixth_gear")

	Global.fight_dice_rolled = 0
	_add("metronome")
	for i in 19:
		_fake_roll("blue", 1)
	var hp_before := _enemy_hp()
	var n_enemies := get_tree().get_nodes_in_group("enemies").size()
	check("Metronome: silent for the first 19 dice", _enemy_hp() == hp_before)
	# Health floors at 0, so a 20-damage AoE onto an 8 HP Satyr only removes 8 - expect the
	# per-enemy CAPPED total, not 20 x enemies (that naive form failed while the relic was
	# working correctly).
	var expected := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		expected += mini(20, e.stats.health)
	_fake_roll("blue", 1)
	var dealt := hp_before - _enemy_hp()
	check("Metronome: 20th die deals 20 to ALL enemies",
			dealt == expected, "dealt %d, expected %d across %d enemies" % [dealt, expected, n_enemies])
	hp_before = _enemy_hp()
	_fake_roll("blue", 1)
	check("Metronome: does not fire again after 20", _enemy_hp() == hp_before,
			str(hp_before - _enemy_hp()))
	await _remove("metronome")


func _scenario_misc() -> void:
	_section("per-roll relics")

	var hp_before := _enemy_hp()
	_add("hunting_bow")
	_fake_roll("blue", 6)
	check("Hunting Bow: a 6 deals 3 (nerfed from 5)", hp_before - _enemy_hp() == 3,
			str(hp_before - _enemy_hp()))
	await _remove("hunting_bow")

	# Back to Strength on 2026-08-31, reversing the 2026-08-24 switch to 6 Block. Both
	# halves are asserted: the Strength arrives AND no Block is handed out, so a partial
	# revert that left the BlockEffect in place would still fail here.
	_add("giants_signet")
	var b0 := _block()
	var s0 := _strength()
	_fake_roll("giant", 10)
	check("Giant's Signet: 10+ grants 2 Strength", _strength() == s0 + 2, str(_strength() - s0))
	check("Giant's Signet: no longer grants Block", _block() == b0)
	s0 = _strength()
	_fake_roll("giant", 9)
	check("Giant's Signet: 9 grants nothing", _strength() == s0)
	await _remove("giants_signet")

	# Echo Chamber: once per turn.
	Global.echo_chamber_fired_this_turn = false
	Global.blue_dice_current_amount = 0
	_add("echo_chamber")
	Global.roll_history = [4, 4]
	_fake_roll("blue", 4)
	var after_first: int = Global.blue_dice_current_amount
	check("Echo Chamber: a repeat charges a Blue Dice", after_first >= 1, str(after_first))
	Global.blue_dice_current_amount = 0
	Global.roll_history = [4, 4, 4]
	_fake_roll("blue", 4)
	check("Echo Chamber: second repeat in the SAME turn does nothing",
			Global.blue_dice_current_amount == 0, str(Global.blue_dice_current_amount))
	Global.echo_chamber_fired_this_turn = false   # what dice_interface does at turn start
	Global.roll_history = [4, 4]
	_fake_roll("blue", 4)
	check("Echo Chamber: pays again next turn", Global.blue_dice_current_amount >= 1,
			str(Global.blue_dice_current_amount))
	await _remove("echo_chamber")

	# Haggler's Loupe writes a Global, so its cleanup matters run-wide.
	Global.dice_price_discount = 0.0
	_add("hagglers_loupe")
	check("Haggler's Loupe: 10% discount applied", is_equal_approx(Global.dice_price_discount, 0.10),
			str(Global.dice_price_discount))
	await _remove("hagglers_loupe")
	check("Haggler's Loupe: discount cleared on removal",
			is_equal_approx(Global.dice_price_discount, 0.0), str(Global.dice_price_discount))


func _await_until(predicate: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	push_error("timeout waiting for condition")
