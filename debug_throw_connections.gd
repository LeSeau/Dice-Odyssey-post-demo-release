extends Node

# Regression harness for the THROW != ROLL contract (Julien, 2026-08-29).
#
# History: between 2026-07-23 and 2026-08-29 this file asserted the OPPOSITE rule ("a thrown
# die counts as a die you rolled") - eighteen listeners opted into Events.dice_thrown_landed
# and Global.report_thrown_die_landed bumped five roll counters. All of that was removed. The
# checks below are the inverted versions of the old ones, plus the positive half the old
# harness never covered (a throw must still DEAL its damage).
#
# The contract, in one line: a thrown die deals its RAW face value, plus Trebuchet's flat
# per-throw bonus, times the TARGET's own DMG_TAKEN (Exposed) - and touches nothing else.
#
# Boots a REAL battle so damage goes through the real Card._land_thrown_die -> DamageEffect
# -> Enemy.take_damage path rather than a simulation of it.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_throw_connections.tscn \
#       --rendering-driver opengl3 --position 2000,2000
#
# NEGATIVE CONTROL (house rule - a separation test that cannot fail proves nothing): restore
# the counter bumps in Global.report_thrown_die_landed and section B must go red.

const FIGHT := "res://battles/tier_1_crab_satyr.tres"

const THROW_SCRIPTS := [
	"res://custom_resources/card.gd",
	"res://characters/warrior/cards/meteor.gd",
	"res://characters/warrior/cards/meteor_plus.gd",
	"res://characters/warrior/cards/cursed_toss.gd",
	"res://characters/warrior/cards/cursed_toss_plus.gd",
	"res://characters/warrior/cards/pixie_volley.gd",
	"res://characters/warrior/cards/dice_avalanche.gd",
	"res://characters/warrior/cards/dice_avalanche_plus.gd",
	"res://characters/warrior/cards/fastball.gd",
	"res://characters/warrior/cards/fastball_plus.gd",
	"res://characters/warrior/cards/windfall.gd",
	"res://characters/warrior/cards/windfall_plus.gd",
	"res://characters/warrior/cards/rampart.gd",
	"res://characters/warrior/cards/rampart_plus.gd",
	"res://characters/warrior/cards/all_in.gd",
	"res://characters/warrior/cards/kickstart.gd",
	"res://characters/warrior/cards/trebuchet.gd",
	"res://statuses/artillery.gd",
]

# Every script that used to opt into dice_thrown_landed. None of them may reference it now.
const FORMER_LISTENERS := [
	"res://relics/consolation_chip.gd", "res://relics/crown.gd",
	"res://relics/giants_signet.gd", "res://relics/house_money.gd",
	"res://relics/hunting_bow.gd", "res://relics/jackpot_pin.gd",
	"res://relics/metronome.gd", "res://relics/needle_die.gd",
	"res://relics/prismatic_lens.gd", "res://relics/sixth_gear.gd",
	"res://relics/snake_eyes_charm.gd", "res://relics/the_one.gd",
	"res://relics/underdog_ring.gd", "res://statuses/effigy.gd",
	"res://statuses/greedy.gd", "res://statuses/ruptured.gd",
	"res://statuses/status_hardened_grip.gd", "res://scenes/card_ui/card_ui.gd",
]

# Relics whose trigger faces the sweep below covers: 1, 2, 6, 10 on several types.
const WATCHED_RELICS := [
	"res://relics/crown.tres", "res://relics/metronome.tres",
	"res://relics/sixth_gear.tres", "res://relics/hunting_bow.tres",
	"res://relics/snake_eyes_charm.tres", "res://relics/needle_die.tres",
	"res://relics/underdog_ring.tres", "res://relics/the_one.tres",
	"res://relics/giants_signet.tres", "res://relics/prismatic_lens.tres",
]

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _relic_handler: RelicHandler
var _player: Player
var _probe_hits: Array = []
var _relic_uis: Array = []


func check(label: String, ok: bool, detail := "") -> void:
	checks += 1
	var suffix := ("  [" + detail + "]") if detail != "" else ""
	if ok:
		print("PASS  ", label, suffix)
	else:
		fails += 1
		print("FAIL  ", label, suffix)


func _section(title: String) -> void:
	print("\n--- ", title, " ---")


func _on_probe(dice_type: String, value: int) -> void:
	_probe_hits.append([dice_type, value])


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	# Suppress achievement unlocks/toasts while the harness pokes counters.
	Global.tutorial_on = true
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)

	_section("A. scripts still compile")
	for path in THROW_SCRIPTS:
		var s = load(path)
		check("compiles: " + path.get_file(), s != null and s.can_instantiate())
	var pool = load("res://characters/warrior/warrior_draftable_cards.tres")
	check("draftable pool loads (all card scripts compile)", pool != null)
	var relic_pool = load("res://treasure_relic_pool.tres")
	check("treasure relic pool loads", relic_pool != null)

	_section("A2. no script opts into dice_thrown_landed any more")
	for path in FORMER_LISTENERS:
		var f := FileAccess.open(path, FileAccess.READ)
		var body := f.get_as_text() if f != null else ""
		check("no dice_thrown_landed in " + path.get_file(),
				body != "" and not body.contains("dice_thrown_landed"))

	await _boot_battle()
	await _scenario_counters_untouched()
	_scenario_infusion_faces()
	await _scenario_no_relic_fires()
	await _scenario_throw_still_deals_damage()

	print("\n==== THROW != ROLL: %d checks, %d fail(s) ====" % [checks, fails])
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
	_player = get_tree().get_first_node_in_group("player") as Player
	check("battle booted", _player != null and _enemies().size() >= 1)


# ---------------------------------------------------------------------------------------
# B. The funnel moves no roll counter, but still emits for throw-specific content.
#    (This is the section the negative control must break.)
# ---------------------------------------------------------------------------------------
func _scenario_counters_untouched() -> void:
	_section("B. report_thrown_die_landed touches no roll counter")
	Global.fight_dice_rolled = 4
	Global.dice_amount_rolled_this_turn = 2
	Global.dice_types_rolled_this_turn = {"blue": true}
	Global.sixes_rolled_this_fight = 1
	Global.run_stat_dice_rolled = 7
	Global.roll_value = 5
	Global.roll_history = [2, 3]
	Global.last_roll = 3

	_probe_hits.clear()
	Events.dice_thrown_landed.connect(_on_probe)
	# A 6 on a type never rolled this turn: would have moved every single counter before.
	Global.report_thrown_die_landed("magma", 6)
	Events.dice_thrown_landed.disconnect(_on_probe)

	check("fight_dice_rolled unchanged", Global.fight_dice_rolled == 4,
			str(Global.fight_dice_rolled))
	check("dice_amount_rolled_this_turn unchanged", Global.dice_amount_rolled_this_turn == 2,
			str(Global.dice_amount_rolled_this_turn))
	check("dice_types_rolled_this_turn unchanged (no 'magma' key)",
			not Global.dice_types_rolled_this_turn.has("magma"),
			str(Global.dice_types_rolled_this_turn.keys()))
	check("sixes_rolled_this_fight unchanged (thrown 6 does not count)",
			Global.sixes_rolled_this_fight == 1, str(Global.sixes_rolled_this_fight))
	check("run_stat_dice_rolled unchanged", Global.run_stat_dice_rolled == 7,
			str(Global.run_stat_dice_rolled))
	# Power chain: was already correct before this pass, guarded here so it stays that way.
	check("roll_value unchanged", Global.roll_value == 5, str(Global.roll_value))
	check("roll_history unchanged", Global.roll_history == [2, 3], str(Global.roll_history))
	check("last_roll unchanged", Global.last_roll == 3, str(Global.last_roll))
	# The hook itself survives, for content that is deliberately about throwing.
	check("dice_thrown_landed still emitted with (type, value)",
			_probe_hits == [["magma", 6]], str(_probe_hits))


# ---------------------------------------------------------------------------------------
# C. Thrown faces still respect infusions (unchanged by this pass, guarded).
# ---------------------------------------------------------------------------------------
func _scenario_infusion_faces() -> void:
	_section("C. thrown faces stay infusion-aware")
	Global.dice_infusions = {}
	check("evil base faces", Card.thrown_faces_for("evil") == [0, 6, 6, 6])
	Global.dice_infusions = {"evil": "repented"}
	var repented: Array = Card.thrown_faces_for("evil")
	check("repented evil drops the crack", not repented.has(0) and repented.has(6))
	Global.dice_infusions = {"giant": "bulky"}
	var bulky: Array = Card.thrown_faces_for("giant")
	check("bulky giant uses override (no 1, has 12)", not bulky.has(1) and bulky.has(12))
	Global.dice_infusions = {}


# ---------------------------------------------------------------------------------------
# D. With every value-triggered relic equipped, a barrage of thrown dice covering all their
#    trigger faces changes NOTHING. One aggregate sweep rather than ten one-off checks: if
#    any listener creeps back in, one of these totals moves.
# ---------------------------------------------------------------------------------------
func _scenario_no_relic_fires() -> void:
	_section("D. no roll-triggered relic fires off a throw")
	var relic_ui_scene = load("res://scenes/relic_handler/relic_ui.tscn")
	for path in WATCHED_RELICS:
		var ui: RelicUI = relic_ui_scene.instantiate()
		add_child(ui)
		ui.relic = load(path)
		_relic_uis.append(ui)
	await get_tree().process_frame

	# Hardened Grip (1 Block per die) and Ruptured (3 damage per die) were opt-ins too.
	var grip: Status = load("res://statuses/status_hardened_grip.tres").duplicate()
	_player.status_handler.add_status(grip)
	await get_tree().process_frame

	# Total HP across ALL enemies, not just the first: Hunting Bow and Needle Die hit a RANDOM
	# enemy, so checking one body lets a re-added listener slip through half the time.
	var hp_before := _total_enemy_hp()
	var block_before: int = _player.stats.block
	var power_before: int = Global.roll_value
	var strength_before := _player_strength()
	var blue_before: int = Global.blue_dice_current_amount
	Global.fight_dice_rolled = 9      # Crown fires on the 10th, Sixth Gear on every 8th
	Global.dice_amount_rolled_this_turn = 0
	Global.dice_types_rolled_this_turn = {}
	Global.has_rolled_1_this_fight = false

	# Every trigger face the watched relics care about: 1 (Snake Eyes / Needle Die / The One /
	# Underdog), 2 (Underdog), 6 (Hunting Bow), 10-12 (Giant's Signet), across 4 types
	# (Prismatic Lens's rainbow) and enough dice to cross Crown's 10th and Sixth Gear's 8th.
	for i in 3:
		Global.report_thrown_die_landed("blue", 1)
		Global.report_thrown_die_landed("green", 2)
		Global.report_thrown_die_landed("magma", 6)
		Global.report_thrown_die_landed("giant", 11)
	await _settle(0.5)

	check("no enemy damage (Hunting Bow / Needle Die / Ruptured silent)",
			_total_enemy_hp() == hp_before, "%d -> %d" % [hp_before, _total_enemy_hp()])
	check("no Block gained (Underdog Ring / Giant's Signet / Hardened Grip silent)",
			_player.stats.block == block_before,
			"%d -> %d" % [block_before, _player.stats.block])
	check("no Power gained (Sixth Gear silent)", Global.roll_value == power_before,
			"%d -> %d" % [power_before, Global.roll_value])
	check("no Strength gained (Snake Eyes Charm silent)",
			_player_strength() == strength_before,
			"%d -> %d" % [strength_before, _player_strength()])
	check("no die Charged (Crown / The One / Prismatic Lens silent)",
			Global.blue_dice_current_amount == blue_before,
			"%d -> %d" % [blue_before, Global.blue_dice_current_amount])
	check("fight_dice_rolled still 9 after 12 throws (Crown's 10th never reached)",
			Global.fight_dice_rolled == 9, str(Global.fight_dice_rolled))

	for ui in _relic_uis:
		var r: Relic = ui.relic
		if r != null:
			r.deactivate_relic(ui)


# ---------------------------------------------------------------------------------------
# E. The positive half: a throw must still HIT, and only Trebuchet + the target's own
#    Exposed may scale it. The old harness never covered any of this.
# ---------------------------------------------------------------------------------------
func _scenario_throw_still_deals_damage() -> void:
	_section("E. a throw still deals raw damage (+Trebuchet, +target Exposed, never Strength)")
	var meteor: Card = load("res://characters/warrior/cards/card_meteor.tres")
	var enemy: Node = _enemies()[0]
	# Keep it alive through four landings.
	enemy.stats.max_health = 999
	enemy.stats.health = 999
	await get_tree().process_frame

	# 1) raw face value, no bonuses at all
	Global.thrown_dice_bonus_fight = 0
	var hp: int = enemy.stats.health
	meteor._land_thrown_die(get_tree(), enemy, 4, 0.0, null, "giant", 4)
	await _settle(0.4)
	var raw: int = hp - enemy.stats.health
	check("raw thrown die deals exactly its face value", raw == 4, str(raw))

	# 2) Strength must NOT reach it - the whole point of the 2026-08-20 ruling
	var muscle: Status = load("res://statuses/muscle.tres").duplicate()
	muscle.stacks = 5
	_player.status_handler.add_status(muscle)
	await get_tree().process_frame
	check("player actually has Strength for the test", _player_strength() >= 5,
			str(_player_strength()))
	hp = enemy.stats.health
	meteor._land_thrown_die(get_tree(), enemy, 4, 0.0, null, "giant", 4)
	await _settle(0.4)
	var with_strength: int = hp - enemy.stats.health
	check("Strength does NOT scale a thrown die", with_strength == raw,
			"%d vs %d" % [with_strength, raw])

	# 3) Trebuchet's flat per-throw bonus still applies
	Global.thrown_dice_bonus_fight = 3
	hp = enemy.stats.health
	meteor._land_thrown_die(get_tree(), enemy, 4, 0.0, null, "giant", 4)
	await _settle(0.4)
	var with_treb: int = hp - enemy.stats.health
	check("Trebuchet's +3 still applies to a thrown die", with_treb == raw + 3,
			"%d vs %d" % [with_treb, raw + 3])

	# 4) the TARGET's own Exposed still applies (it lives in take_damage, not in our scaling)
	var exposed: Status = load("res://statuses/exposed.tres").duplicate()
	exposed.stacks = 2
	enemy.status_handler.add_status(exposed)
	await get_tree().process_frame
	hp = enemy.stats.health
	meteor._land_thrown_die(get_tree(), enemy, 4, 0.0, null, "giant", 4)
	await _settle(0.4)
	var with_exposed: int = hp - enemy.stats.health
	check("target's Exposed still amplifies a thrown die", with_exposed > with_treb,
			"%d vs %d" % [with_exposed, with_treb])

	Global.thrown_dice_bonus_fight = 0


# ---------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------
func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _total_enemy_hp() -> int:
	var total := 0
	for e in _enemies():
		total += int(e.stats.health)
	return total


# muscle.tres carries id "strength", not "muscle" - looking it up by the wrong key returns 0
# and silently fakes a pass.
func _player_strength() -> int:
	var s: Status = _player.status_handler._get_status("strength")
	return s.stacks if s != null else 0


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _await_until(predicate: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
