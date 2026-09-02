extends Node

# Regression harness for the three enemies added on 2026-09-01.
#
# What it pins:
#   Quartermaster - Rationed caps ROLLS per turn, the cap resets each turn, a Ricochet reroll
#     is exempt, and killing it lifts the cap. Beats: Levy 12 / Requisition 6 + 2 Str, both
#     capped at 2 in a row.
#   Slanderer     - Whisper plants a Slander card in the DISCARD pile (not the draw pile),
#     never twice in a row, and the pair opens out of sync via forced_opener_action_id. The
#     card is NOT Celestial: binning it needs a roll and eats the bank, which is the real tax.
#   Famished      - fixed Gnaw / Burrow / Devour cycle, and Gorge grants +3 Str only on turns
#     the player ends with an empty Dice pool.
#
# Sections A-C simulate action picking (same recipe as debug_t0_patterns). Sections D-F boot a
# REAL battle.tscn: the spend cap lives in dice.gd's roll path and Gorge hangs off
# player_turn_ended, so simulating either would prove nothing.
#
# NEGATIVE CONTROLS (house rule): see _negative_control_note() at the bottom.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_new_enemies.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT_QM := "res://battles/tier_2_quartermaster.tres"
const FIGHT_QM_SCENE := "res://battles/tier_2_quartermaster.tscn"
const FIGHT_SL_SCENE := "res://battles/tier_1_slanderers.tscn"
const FIGHT_FA := "res://battles/tier_2_famished.tres"
const FIGHT_FA_SCENE := "res://battles/tier_2_famished.tscn"

const LONG_RUN := 400
const OPENER_TRIALS := 60

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
	seed(20260901)

	_section_quartermaster_pattern()
	_section_slanderer_pattern()
	_section_famished_pattern()

	await _section_spend_cap()
	await _section_slander_injection()
	await _section_gorge()

	print("\n==== NEW ENEMIES: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- helpers

func _load_fight(path: String) -> Node:
	var scene: PackedScene = load(path)
	var inst: Node = scene.instantiate()
	add_child(inst)
	return inst


func _enemy_named(root: Node, part: String) -> Enemy:
	for child in root.get_children():
		if child is Enemy and String(child.name).to_lower().contains(part.to_lower()):
			return child
	return null


# Replicates the last_action bookkeeping Enemy.do_turn() does, without running the tweens.
func _simulate(enemy: Enemy, turns: int) -> Array[String]:
	var seq: Array[String] = []
	enemy.last_action = ""
	enemy.last_action_count = 0
	for t in range(turns):
		Global.fight_turn = t
		enemy.update_action()
		var action: EnemyAction = enemy.current_action
		if action == null:
			seq.append("<null>")
			continue
		seq.append(action.action_id)
		if enemy.last_action == action.action_id:
			enemy.last_action_count += 1
		else:
			enemy.last_action = action.action_id
			enemy.last_action_count = 1
	return seq


func _max_run(seq: Array[String], id: String) -> int:
	var best := 0
	var current := 0
	for entry: String in seq:
		if entry == id:
			current += 1
			best = maxi(best, current)
		else:
			current = 0
	return best


func _count(seq: Array[String], id: String) -> int:
	var total := 0
	for entry: String in seq:
		if entry == id:
			total += 1
	return total


# ---------------------------------------------------------------- A: Quartermaster beats

func _section_quartermaster_pattern() -> void:
	print("\n--- A: Quartermaster beats ---")
	var fight := _load_fight(FIGHT_QM_SCENE)
	var qm := _enemy_named(fight, "quartermaster")
	if qm == null:
		check("quartermaster found", false)
		return

	var seq := _simulate(qm, LONG_RUN)
	check("it attacks EVERY turn - no guard, no idle", not seq.has("<null>") and _count(seq, "") == 0)
	check("Levy capped at 2 in a row", _max_run(seq, "quartermaster_levy") <= 2,
			"max run %d" % _max_run(seq, "quartermaster_levy"))
	check("Requisition capped at 2 in a row", _max_run(seq, "quartermaster_requisition") <= 2,
			"max run %d" % _max_run(seq, "quartermaster_requisition"))
	var levy_share := 100.0 * _count(seq, "quartermaster_levy") / LONG_RUN
	check("Levy is the majority beat (~55-60%)", levy_share > 45.0 and levy_share < 70.0,
			"%.0f%%" % levy_share)
	fight.queue_free()


# ---------------------------------------------------------------- B: Slanderer beats

func _section_slanderer_pattern() -> void:
	print("\n--- B: Slanderer beats + out-of-sync openers ---")
	var fight := _load_fight(FIGHT_SL_SCENE)
	var a := _enemy_named(fight, "slanderer a")
	var b := _enemy_named(fight, "slanderer b")
	if a == null or b == null:
		check("both slanderers found", false)
		return

	check("A is pinned to Whisper on turn 1", a.forced_opener_action_id == "slanderer_whisper",
			a.forced_opener_action_id)
	check("B is pinned to Sneer on turn 1", b.forced_opener_action_id == "slanderer_sneer",
			b.forced_opener_action_id)

	var desync := 0
	for i in range(OPENER_TRIALS):
		var oa := _simulate(a, 1)
		var ob := _simulate(b, 1)
		if oa[0] != ob[0]:
			desync += 1
	# The whole point of the pair: without the override both are a coin flip and land the same
	# beat about half the time, which front-loads the junk.
	check("the pair NEVER opens on the same beat", desync == OPENER_TRIALS,
			"%d/%d" % [desync, OPENER_TRIALS])

	var seq := _simulate(a, LONG_RUN)
	check("Whisper never twice in a row", _max_run(seq, "slanderer_whisper") <= 1,
			"max run %d" % _max_run(seq, "slanderer_whisper"))
	check("Sneer capped at 2 in a row", _max_run(seq, "slanderer_sneer") <= 2,
			"max run %d" % _max_run(seq, "slanderer_sneer"))
	fight.queue_free()


# ---------------------------------------------------------------- C: Famished beats

func _section_famished_pattern() -> void:
	print("\n--- C: Famished cycle ---")
	var fight := _load_fight(FIGHT_FA_SCENE)
	var fa := _enemy_named(fight, "famished")
	if fa == null:
		check("famished found", false)
		return

	var seq := _simulate(fa, 9)
	var expected: Array[String] = []
	for i in range(3):
		expected.append_array(["famished_gnaw", "famished_burrow", "famished_devour"])
	check("9 turns are gnaw/burrow/devour repeating", seq == expected, ", ".join(seq))
	check("no randomness: a second run is identical", _simulate(fa, 9) == seq)
	fight.queue_free()


# ---------------------------------------------------------------- D: the spend cap

func _section_spend_cap() -> void:
	print("\n--- D: Rationed caps rolls per turn (real battle) ---")
	Global.fight_turn = 0
	await _boot_battle(FIGHT_QM, 2)

	check("the cap is live from turn 1", Global.dice_spend_cap == 5,
			"cap %d" % Global.dice_spend_cap)

	# Give the player plenty of Dice so the cap, not the pool, is what stops them.
	Global.blue_dice_max_amount = 12
	Global.blue_dice_current_amount = 12
	Global.dice_type = "blue"
	Global.dice_amount_rolled_this_turn = 0

	var dice: Node = _battle.get_node_or_null("ActiveDice")
	if dice == null:
		check("ActiveDice node found", false)
		return

	var rolled := 0
	for i in range(9):
		var before: int = Global.dice_amount_rolled_this_turn
		dice.roll_dice()
		await _await_until(func() -> bool: return not dice._roll_in_progress, 4.0)
		if Global.dice_amount_rolled_this_turn > before:
			rolled += 1
	check("exactly 5 rolls got through, the other 4 were refused", rolled == 5,
			"%d rolled" % rolled)
	check("Dice were NOT spent by the refused rolls", Global.blue_dice_current_amount == 7,
			"%d left of 12" % Global.blue_dice_current_amount)

	# A reroll replaces the roll you already made, so it must stay legal at the cap.
	check("a Ricochet reroll is exempt at the cap", not dice._spend_cap_blocks_roll(true))
	check("an ordinary roll is refused at the cap", dice._spend_cap_blocks_roll(false))

	# The counter is reset by player_handler.start_turn, so the cap is per TURN, not per fight.
	Global.dice_amount_rolled_this_turn = 0
	check("the allowance comes back next turn", not dice._spend_cap_blocks_roll(false))

	# Killing it lifts the restriction - otherwise the cap outlives the enemy imposing it.
	var qm := _find_enemy("Quartermaster")
	if qm != null:
		qm.take_damage(999, Modifier.Type.DMG_DEALT)
		await get_tree().process_frame
		await get_tree().process_frame
	check("killing it lifts the cap", Global.dice_spend_cap == 0,
			"cap %d" % Global.dice_spend_cap)


# ---------------------------------------------------------------- E: junk injection

func _section_slander_injection() -> void:
	print("\n--- E: Slander lands in the DISCARD pile ---")
	var before_discard: int = _battle.char_stats.discard.cards.size()
	var before_draw: int = _battle.char_stats.draw_pile.cards.size()

	var card: Card = load("res://characters/warrior/cards/card_slander.tres").duplicate()
	Events.add_card_to_discard_requested.emit(card, Vector2.ZERO)
	await get_tree().process_frame

	check("discard pile grew by exactly 1",
			_battle.char_stats.discard.cards.size() == before_discard + 1,
			"%d -> %d" % [before_discard, _battle.char_stats.discard.cards.size()])
	check("the DRAW pile was not touched",
			_battle.char_stats.draw_pile.cards.size() == before_draw)

	var planted: Card = _battle.char_stats.discard.cards.back()
	check("it is the Slander card", planted.id == "card_slander", planted.id)
	check("it exhausts when played", planted.exhausts)
	# The tax IS the price of binning it. A Celestial Slander would be free tempo, so it must
	# be non-Celestial (needs a roll first) and it must reset the bank like an ordinary card.
	check("it is NOT Celestial - binning it costs a roll",
			not planted.can_play_without_dice)
	check("no requirement, so it is never stuck in hand once you have rolled",
			planted.requirement == Card.Requirement.NONE)
	check("flagged NORMAL, not SUPPORT (SUPPORT means 'does not reset your Power')",
			planted.rarity == Card.Rarity.NORMAL)

	# Behavioural, through the real path: a live battle has dice.gd listening to
	# dice_roll_reset. Force blue first - the red branch defers the wipe by a second.
	Global.dice_type = "blue"
	Global.roll_value = 9
	Global.roll_history = [9]
	planted.apply_effects([], null)
	await get_tree().process_frame
	check("playing it wipes the banked Power", Global.roll_value == 0,
			"roll_value left at %d" % Global.roll_value)
	check("and clears the roll chain, so the next card needs a fresh roll",
			Global.roll_history.is_empty(), "history %s" % str(Global.roll_history))
	# It must never turn up in a reward screen or a shop.
	var pool: CardPile = load("res://characters/warrior/warrior_draftable_cards.tres")
	var draftable := false
	for entry in pool.cards:
		if entry != null and entry.id == "card_slander":
			draftable = true
	check("it is NOT in the draftable pool", not draftable)


# ---------------------------------------------------------------- F: Gorge

func _section_gorge() -> void:
	print("\n--- F: Gorge feeds on an empty Dice pool (real battle) ---")
	Global.fight_turn = 0
	await _boot_battle(FIGHT_FA, 2)

	var fa := _find_enemy("Famished")
	if fa == null:
		check("famished present in the booted battle", false)
		return

	# Turn ended with Dice still in hand: it must NOT grow.
	Global.blue_dice_current_amount = 2
	var str_before := _enemy_strength(fa)
	Events.player_turn_ended.emit()
	await get_tree().process_frame
	check("no Strength when you end the turn holding Dice",
			_enemy_strength(fa) == str_before,
			"%d -> %d" % [str_before, _enemy_strength(fa)])

	# Now empty every pool and end again.
	for type: String in Global.DICE_TYPE_ORDER:
		Global.set(type + "_dice_current_amount", 0)
	check("Global.dice_pool_empty() agrees the pool is empty", Global.dice_pool_empty())
	str_before = _enemy_strength(fa)
	Events.player_turn_ended.emit()
	await get_tree().process_frame
	check("+3 Strength when you end the turn empty",
			_enemy_strength(fa) == str_before + 3,
			"%d -> %d" % [str_before, _enemy_strength(fa)])

	# A single leftover die of ANY type is enough to starve it.
	Global.mech_dice_current_amount = 1
	check("one leftover die of any type starves it", not Global.dice_pool_empty())
	str_before = _enemy_strength(fa)
	Events.player_turn_ended.emit()
	await get_tree().process_frame
	check("no Strength with a single die left",
			_enemy_strength(fa) == str_before)


# ---------------------------------------------------------------- plumbing

func _enemy_strength(enemy: Enemy) -> int:
	for child in enemy.status_handler.get_children():
		var ui := child as StatusUI
		if ui != null and ui.status != null and ui.status.id == "strength":
			return ui.status.stacks
	return 0


func _find_enemy(display_name: String) -> Enemy:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.stats != null and enemy.stats.enemy_name == display_name:
			return enemy
	return null


func _boot_battle(fight: String, tier: int) -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		await get_tree().process_frame
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
	_battle.battle_stats = load(fight)
	_battle.act_tier = tier
	relic_handler.add_relic(warrior.starting_relic)

	var before := hands_drawn
	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > before, 15.0)


func _await_until(cond: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


# NEGATIVE CONTROLS, for whoever touches this next:
#   1. Make dice.gd::_spend_cap_blocks_roll() `return false` -> section D loses the refusal
#      checks (all 9 rolls get through).
#   2. Delete the enemy_died hook in rationed.gd -> "killing it lifts the cap" goes red.
#   3. Point slanderer_whisper_action at add_card_to_hand_requested instead -> section E's
#      discard/draw split goes red, which is the whole reason that signal exists.
#   4. Drop the Global.dice_pool_empty() guard in gorge.gd -> "no Strength when you end the
#      turn holding Dice" goes red.
#   5. Clear forced_opener_action_id on either Slanderer -> the desync check falls to ~50%.
