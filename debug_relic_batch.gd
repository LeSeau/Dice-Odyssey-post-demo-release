extends Node

# Verification harness for the 2026-08-23 RELIC BATCH (21 new relics).
#
# Two halves:
#   A. Data integrity - every .tres loads, resolves its script and icon, has a unique id that
#      matches its filename, is registered in the right pool(s), and its icon is SQUARE
#      (relic_ui.tscn draws icons with KEEP_ASPECT_COVERED, so a non-square icon silently
#      loses its long axis - the House Money "cut in half" bug from 2026-07-11).
#   B. Behaviour - boots a REAL battle.tscn (same recipe as debug_golem_carryover.gd) and
#      drives each relic through the actual signal it hangs off, asserting the effect.
#
# Every behaviour scenario adds its relic, tests it, then REMOVES it, so the flag-setting
# relics (Golem Heart, Mortar Trowel, Haggler's Loupe, Worm's Eye Lens) also prove their
# deactivate_relic cleans up - a leaked flag would be a run-wide bug.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_relic_batch.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"

const NEW_RELICS := [
	"underdog_ring", "needle_die", "worms_eye_lens", "sixth_gear", "conductors_baton",
	"giants_signet", "pilot_light", "marked_deck", "consolation_chip", "jackpot_pin",
	"blood_chalice", "whetstone_pendant", "mortar_trowel", "thorned_plate", "fuel_gauge",
	"stray_die", "alms_box", "hagglers_loupe",
	"golem_heart",
]
# Deliberately shop-only: a Giant-specific relic in a treasure chest is a dead chest for a
# player who never bought a Giant die.
const SHOP_ONLY := ["giants_signet"]

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _relic_handler: RelicHandler
var _player: Player


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

	_section("A. DATA INTEGRITY")
	_check_resources()
	_check_pools()

	_section("A2. RARITY + SHOP EXCLUSIVITY")
	_check_rarity()

	_section("B. BEHAVIOUR")
	await _boot_battle()
	await _scenario_low_rolls()
	await _scenario_giant_and_red()
	await _scenario_chain_and_count()
	await _scenario_switching()
	await _scenario_defence()
	await _scenario_flags()
	await _scenario_blessing_and_refuel()

	print("\n==== RELIC BATCH: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


func _section(title: String) -> void:
	print("\n--- ", title, " ---")


# ------------------------------------------------------------------ A. data
func _check_resources() -> void:
	var seen_ids := {}
	for rid: String in NEW_RELICS:
		var path := "res://relics/%s.tres" % rid
		var relic := load(path) as Relic
		if relic == null:
			check("load " + rid, false, "resource failed to load")
			continue
		check("load " + rid, true)
		check(rid + " id matches filename", relic.id == rid, relic.id)
		check(rid + " has name", relic.relic_name != "")
		check(rid + " has tooltip", relic.tooltip.strip_edges() != "")
		check(rid + " has icon", relic.icon != null)
		check(rid + " id unique", not seen_ids.has(relic.id), relic.id)
		seen_ids[relic.id] = true
		if relic.icon != null:
			# Explicit ints: Relic.icon is typed as the BASE Texture, which has no
			# get_width(), so `:=` cannot infer and the whole file fails to parse.
			var w: int = relic.icon.get_width()
			var h: int = relic.icon.get_height()
			# Square, or KEEP_ASPECT_COVERED crops the long axis off in the top bar.
			check(rid + " icon square", w == h, "%dx%d" % [w, h])


func _check_pools() -> void:
	var treasure := load("res://treasure_relic_pool.tres") as RelicPool
	var shop := load("res://shop_relic_pool.tres") as RelicPool
	check("treasure pool loads", treasure != null)
	check("shop pool loads", shop != null)
	if treasure == null or shop == null:
		return

	var t_ids := _ids_of(treasure)
	var s_ids := _ids_of(shop)
	check("no null in treasure pool", not t_ids.has(""), str(t_ids.size()) + " entries")
	check("no null in shop pool", not s_ids.has(""), str(s_ids.size()) + " entries")
	check("treasure pool has no duplicate ids", t_ids.size() == _unique(t_ids).size())
	check("shop pool has no duplicate ids", s_ids.size() == _unique(s_ids).size())

	# Both pools now hold the same roster on purpose - shop_only decides availability, so
	# membership is no longer the mechanism (see _check_rarity for the flag's enforcement).
	for rid: String in NEW_RELICS:
		check("shop pool contains " + rid, s_ids.has(rid))
		check("treasure pool contains " + rid, t_ids.has(rid))


const SHOP_ONLY_EXPECTED := ["giants_signet", "hagglers_loupe"]


func _check_rarity() -> void:
	var treasure := load("res://treasure_relic_pool.tres") as RelicPool
	var shop := load("res://shop_relic_pool.tres") as RelicPool

	# Both files must hold the same roster: shop_only is the single source of truth for
	# availability, so a hand-maintained difference between the two would be a second one.
	var t_ids := _ids_of(treasure)
	var s_ids := _ids_of(shop)
	t_ids.sort()
	s_ids.sort()
	check("both pools hold identical rosters", t_ids == s_ids,
			"%d vs %d" % [t_ids.size(), s_ids.size()])

	var counts := {0: 0, 1: 0, 2: 0}
	for relic in treasure.pool:
		if relic != null:
			counts[relic.rarity_tier] = counts[relic.rarity_tier] + 1
	print("     rarity spread: %d common / %d uncommon / %d rare"
			% [counts[0], counts[1], counts[2]])
	check("every tier is populated", counts[0] > 0 and counts[1] > 0 and counts[2] > 0)

	for rid: String in SHOP_ONLY_EXPECTED:
		var relic := load("res://relics/%s.tres" % rid) as Relic
		check(rid + " is flagged shop_only", relic != null and relic.shop_only)

	# The draw must respect the flag: 400 treasure draws, none may be shop-only.
	var handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(handler)
	var stats: CharacterStats = (load("res://characters/warrior/warrior.tres") as CharacterStats).create_instance()

	var leaked := 0
	var drawn := {}
	for _i in 400:
		var relic := treasure.get_random_relic(stats, handler)
		if relic == null:
			continue
		if relic.shop_only:
			leaked += 1
		drawn[relic.rarity_tier] = drawn.get(relic.rarity_tier, 0) + 1
	check("treasure draw never yields a shop-only relic", leaked == 0, str(leaked) + " leaks")

	# The advertised odds are 50/33/17, and they must hold regardless of how many relics sit
	# in each tier - that is the whole reason the draw picks a tier before picking a relic.
	var c: int = drawn.get(0, 0)
	var u: int = drawn.get(1, 0)
	var r: int = drawn.get(2, 0)
	var n := float(c + u + r)
	print("     draw mix over %d: %.0f%% common / %.0f%% uncommon / %.0f%% rare"
			% [n, 100.0 * c / n, 100.0 * u / n, 100.0 * r / n])
	check("common is drawn more often than rare", c > r, "%d vs %d" % [c, r])
	# Generous band: 400 draws is a small sample, this is guarding against the odds being
	# skewed by TIER SIZE (the bug this replaced), not against ordinary variance.
	check("common lands near its 50% weight", absf(100.0 * c / n - 50.0) < 12.0,
			"%.0f%%" % (100.0 * c / n))
	check("rare lands near its 17% weight", absf(100.0 * r / n - 17.0) < 10.0,
			"%.0f%%" % (100.0 * r / n))

	# The shop draw is the ONLY path that can surface a shop-only relic. Over 400 draws of a
	# 48-relic pool it should turn up at least once.
	var shop_saw_exclusive := false
	for _i in 400:
		var relic := shop.get_random_shop_relic(stats, handler)
		if relic != null and relic.shop_only:
			shop_saw_exclusive = true
			break
	check("shop draw CAN yield a shop-only relic", shop_saw_exclusive)

	host.queue_free()


func _ids_of(pool: RelicPool) -> Array[String]:
	var out: Array[String] = []
	for relic in pool.pool:
		out.append("" if relic == null else relic.id)
	return out


func _unique(items: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for item in items:
		if not out.has(item):
			out.append(item)
	return out


# ------------------------------------------------------------------ B. boot
func _boot_battle() -> void:
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)

	_relic_handler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	# Documented harness trap: an HBoxContainer with no Control ancestor collapses to zero size.
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(_relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	_battle.relics = _relic_handler
	_battle.battle_stats = load(FIGHT)
	_battle.act_tier = 1
	# Documented harness trap: without the starting relic (Dice Bag) turn 1 hands out fewer
	# Blue dice than the real game.
	_relic_handler.add_relic(warrior.starting_relic)

	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 15.0)
	_player = get_tree().get_first_node_in_group("player") as Player
	check("battle booted", _player != null)


# Adds a relic, hands back its RelicUI so a scenario can drive it.
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
		# The resource is muscle.tres but its id is "strength" (Muscle and Strength are the
		# same status - see CLAUDE.md).
		if status.id == "strength":
			total += status.stacks
	return total


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _enemy_hp() -> int:
	var total := 0
	for enemy in _enemies():
		total += enemy.stats.health
	return total


# Fires the real roll signal the way dice.gd does: set last_roll, then emit.
#
# ⚠️ dice_interface._on_dice_rolled SPENDS a die of the active type on this signal (guarded by
# `> 0`). Any assertion about a dice COUNT therefore has to zero that type first - see
# _isolate_dice_count - or the relic's +1 and the interface's -1 cancel out and the test lies.
# Both counters move, mirroring global.gd::report_dice_roll. fight_dice_rolled was added
# here on 2026-08-24: Sixth Gear now counts across the fight rather than the turn, and this
# helper only moved the per-turn counter, so the relic looked broken while it was fine.
func _fake_roll(dice_type: String, value: int) -> void:
	Global.dice_type = dice_type
	Global.last_roll = value
	Global.dice_amount_rolled_this_turn += 1
	Global.fight_dice_rolled += 1
	Events.dice_rolled.emit(dice_type, value)


# Zeroing the pool makes the interface's decrement a no-op (it only spends when > 0), so
# whatever the count is afterwards was put there by the relic under test and nothing else.
func _isolate_dice_count(dice_type: String) -> void:
	Global.set(dice_type + "_dice_current_amount", 0)


# Red-specific relics listen to red_dice_rolled, which is emitted separately from dice_rolled
# by dice.gd. Emitting only that one keeps the dice pool out of it entirely.
func _fake_red_roll(value: int) -> void:
	Global.dice_type = "red"
	Global.last_roll = value
	Events.red_dice_rolled.emit()


# ------------------------------------------------------------------ scenarios
func _scenario_low_rolls() -> void:
	_section("low-roll relics")
	_add("underdog_ring")
	var before := _block()
	_fake_roll("blue", 1)
	check("Underdog Ring: 1 grants Block", _block() == before + 2, str(_block() - before))
	before = _block()
	_fake_roll("blue", 2)
	check("Underdog Ring: 2 grants Block", _block() == before + 2)
	before = _block()
	_fake_roll("blue", 3)
	check("Underdog Ring: 3 grants nothing", _block() == before)
	await _remove("underdog_ring")

	_add("needle_die")
	var hp_before := _enemy_hp()
	_fake_roll("blue", 1)
	await get_tree().process_frame
	check("Needle Die: 1 deals damage", _enemy_hp() < hp_before,
			"%d -> %d" % [hp_before, _enemy_hp()])
	hp_before = _enemy_hp()
	_fake_roll("blue", 4)
	await get_tree().process_frame
	check("Needle Die: 4 deals nothing", _enemy_hp() == hp_before)
	await _remove("needle_die")


func _scenario_giant_and_red() -> void:
	_section("giant / red relics")
	_add("giants_signet")
	# Pays Block since 2026-08-24 (was 1 Strength): Strength compounded over a long fight.
	var blk_before := _block()
	_fake_roll("giant", 10)
	check("Giant's Signet: 10 grants Block", _block() == blk_before + 6, str(_block() - blk_before))
	blk_before = _block()
	_fake_roll("giant", 9)
	check("Giant's Signet: 9 grants nothing", _block() == blk_before)
	blk_before = _block()
	_fake_roll("blue", 12)
	check("Giant's Signet: ignores other types", _block() == blk_before)
	await _remove("giants_signet")

	_add("jackpot_pin")
	var str_before := _strength()
	_fake_red_roll(6)
	check("Jackpot Pin: red 6 grants 2 Strength", _strength() == str_before + 2,
			str(_strength() - str_before))
	str_before = _strength()
	_fake_red_roll(5)
	check("Jackpot Pin: red 5 grants nothing", _strength() == str_before)
	await _remove("jackpot_pin")

	_add("consolation_chip")
	_isolate_dice_count("red")
	_fake_red_roll(2)
	check("Consolation Chip: red 2 refunds a die",
			Global.red_dice_current_amount == 1, str(Global.red_dice_current_amount))
	_isolate_dice_count("red")
	_fake_red_roll(3)
	check("Consolation Chip: red 3 refunds nothing",
			Global.red_dice_current_amount == 0, str(Global.red_dice_current_amount))
	await _remove("consolation_chip")

	# Marked Deck arms a flag that dice.gd's roll path consumes on the first RED roll.
	_add("marked_deck")
	check("Marked Deck: armed on pickup", Global.marked_deck_armed)
	await _remove("marked_deck")
	check("Marked Deck: disarmed on removal", not Global.marked_deck_armed)


func _scenario_chain_and_count() -> void:
	_section("chain / count relics")
	_add("conductors_baton")
	Global.roll_history = [3, 4]
	_isolate_dice_count("blue")
	_fake_roll("blue", 5)
	check("Conductor's Baton: chain of 3 does nothing",
			Global.blue_dice_current_amount == 0, str(Global.blue_dice_current_amount))
	Global.roll_history = [3, 4, 5, 6]
	_isolate_dice_count("blue")
	_fake_roll("blue", 6)
	check("Conductor's Baton: chain of 4 Charges",
			Global.blue_dice_current_amount == 1, str(Global.blue_dice_current_amount))
	_isolate_dice_count("blue")
	_fake_roll("blue", 6)
	check("Conductor's Baton: only once per turn",
			Global.blue_dice_current_amount == 0, str(Global.blue_dice_current_amount))
	await _remove("conductors_baton")

	# Counts across the FIGHT since 2026-08-24, not per turn - so the counter that matters
	# is fight_dice_rolled. See debug_relic_rework.gd for the turn-boundary case.
	_add("sixth_gear")
	Global.fight_dice_rolled = 4
	Global.roll_value = 0
	_fake_roll("blue", 3)  # 5th of the fight
	check("Sixth Gear: 5th die grants nothing", Global.roll_value == 0)
	_fake_roll("blue", 3)  # 6th of the fight
	check("Sixth Gear: 6th die grants 4 Power (nerfed 2026-08-24, was 6)",
			Global.roll_value == 4, str(Global.roll_value))
	Global.roll_value = 0
	_fake_roll("blue", 3)  # 7th
	check("Sixth Gear: 7th die grants nothing", Global.roll_value == 0)
	await _remove("sixth_gear")


func _scenario_switching() -> void:
	_section("dice-switch relics")
	# Wayfinder Compass and Diplomat's Seal were CUT from both pools on 2026-08-24.
	# Their files stay on disk (convention) but they are no longer offered, so there is
	# nothing left to regression-test here.


func _scenario_defence() -> void:
	_section("defence relics")
	_add("thorned_plate")
	var hp_before := _enemy_hp()
	Events.player_fully_blocked.emit(null)
	await get_tree().process_frame
	check("Thorned Plate: full block reflects damage", _enemy_hp() < hp_before,
			"%d -> %d" % [hp_before, _enemy_hp()])
	await _remove("thorned_plate")

	_add("mortar_trowel")
	check("Mortar Trowel: sets the carryover cap", Global.block_carryover_cap == 5)
	await _remove("mortar_trowel")
	check("Mortar Trowel: clears the cap on removal", Global.block_carryover_cap == 0)


func _scenario_flags() -> void:
	_section("flag relics")
	# Haggler's Loupe is the one relic that must work OUTSIDE combat, so it is checked
	# against the real pricing function rather than a signal.
	var full: int = Global.current_dice_price("blue")
	_add("hagglers_loupe")
	var discounted: int = Global.current_dice_price("blue")
	check("Haggler's Loupe: discounts dice", discounted < full,
			"%d -> %d" % [full, discounted])
	check("Haggler's Loupe: discount is ~10%",
			absf(float(discounted) / float(full) - 0.90) < 0.02,
			"%.3f" % (float(discounted) / float(full)))
	await _remove("hagglers_loupe")
	check("Haggler's Loupe: price restored on removal",
			Global.current_dice_price("blue") == full)

	_add("golem_heart")
	check("Golem Heart: sets the keep-all flag", Global.keep_all_dice_always)
	await _remove("golem_heart")
	check("Golem Heart: clears the flag on removal", not Global.keep_all_dice_always)

	_add("worms_eye_lens")
	check("Worm's Eye Lens: sets the Max bonus", Global.max_card_damage_bonus == 3)
	# The bonus must apply ONLY while a Max card is resolving.
	var handler := _player.modifier_handler
	Global.playing_card_requirement = -1
	var plain := handler.get_modified_value(10, Modifier.Type.DMG_DEALT)
	Global.playing_card_requirement = Card.Requirement.MAX
	var boosted := handler.get_modified_value(10, Modifier.Type.DMG_DEALT)
	Global.playing_card_requirement = Card.Requirement.MIN
	var min_card := handler.get_modified_value(10, Modifier.Type.DMG_DEALT)
	Global.playing_card_requirement = -1
	check("Worm's Eye Lens: boosts Max cards", boosted == plain + 3,
			"%d vs %d" % [boosted, plain])
	check("Worm's Eye Lens: leaves Min cards alone", min_card == plain)
	check("Worm's Eye Lens: leaves non-card damage alone",
			handler.get_modified_value(10, Modifier.Type.DMG_DEALT) == plain)
	await _remove("worms_eye_lens")
	check("Worm's Eye Lens: clears the bonus on removal", Global.max_card_damage_bonus == 0)

	# Stray Die must pick a type the player does NOT own.
	_add("stray_die")
	var relic := load("res://relics/stray_die.tres") as Relic
	var owned_before := {}
	for dice_type: String in Global.DICE_TYPE_ORDER:
		owned_before[dice_type] = Global.get(dice_type + "_dice_bonus_amount")
	for relic_ui: RelicUI in _relic_handler.relics.get_children():
		if relic_ui.relic and relic_ui.relic.id == "stray_die":
			relic.activate_relic(relic_ui)
	var granted := ""
	for dice_type: String in Global.DICE_TYPE_ORDER:
		var now: int = Global.get(dice_type + "_dice_bonus_amount")
		if now > owned_before[dice_type]:
			granted = dice_type
	check("Stray Die: grants a bonus die", granted != "", granted)
	if granted != "":
		var max_owned: int = Global.get(granted + "_dice_max_amount")
		check("Stray Die: the type is one you do NOT own", max_owned <= 0,
				"%s max=%d" % [granted, max_owned])
	await _remove("stray_die")


func _scenario_blessing_and_refuel() -> void:
	_section("blessing / refuel relics")
	_add("alms_box")
	var before := _block()
	var blessing := load("res://characters/warrior/cards/card_emanation.tres") as Card
	if blessing != null and blessing.type == Card.Type.BLESSING:
		Events.card_played.emit(blessing)
		check("Alms Box: Blessing grants Block", _block() == before + 5, str(_block() - before))
	else:
		check("Alms Box: found a Blessing card to test with", false)
	before = _block()
	var attack := load("res://characters/warrior/cards/warrior_axe_attack1.tres") as Card
	Events.card_played.emit(attack)
	check("Alms Box: non-Blessing grants nothing", _block() == before)
	await _remove("alms_box")

	# Cumulative since 2026-08-24: 20 Power refuelled across the fight pays 3 Strength once.
	_add("fuel_gauge")
	Global.refueled_power_this_fight = 0
	var fg_str := _strength()
	Events.refuel_happened.emit(3)
	check("Fuel Gauge: a small refuel alone does not pay", _strength() == fg_str)
	Events.refuel_happened.emit(20)
	check("Fuel Gauge: crossing 20 total pays 3 Strength", _strength() == fg_str + 3,
			str(_strength() - fg_str))
	await _remove("fuel_gauge")

	_add("whetstone_pendant")
	var str_before := _strength()
	var pendant := load("res://relics/whetstone_pendant.tres") as Relic
	for relic_ui: RelicUI in _relic_handler.relics.get_children():
		if relic_ui.relic and relic_ui.relic.id == "whetstone_pendant":
			pendant.activate_relic(relic_ui)
	check("Whetstone Pendant: grants 2 Strength", _strength() == str_before + 2)
	await _remove("whetstone_pendant")

	# Pilot Light routes through starting_power_next_turn (see the script for why a direct
	# roll_value bump would be wiped by dice.gd's turn-start assignment).
	# Fight-start only since 2026-08-24 (was every turn), so battle_started is the hook.
	_add("pilot_light")
	Global.starting_power_next_turn = 0
	Events.battle_started.emit()
	check("Pilot Light: banks 3 Power at fight start", Global.starting_power_next_turn == 3,
			str(Global.starting_power_next_turn))
	await _remove("pilot_light")


func _await_until(predicate: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	push_error("timeout waiting for condition")
