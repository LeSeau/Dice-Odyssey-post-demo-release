extends Node

## Harness for the cadence promotion (enemy_design_analysis_2026-08.md §9.4), 2026-08-13.
## Root-level debug_* scene, auto-excluded from the web export by the preset's exclude_filter.
## COMMITTED (2026-09-07) - it pins gameplay rules, not feel: the fixed guard cadences and the
## Ink Tide repeat cap. Edit any of those enemies and run this before trusting the result.
##
## Boots the REAL AI scenes (never --script: without autoloads every .tres silently loads its
## script properties at their defaults) and drives EnemyActionPicker.get_action() across a range
## of fight_turn values, asserting the exact beat each turn produces.
##
## What it is actually guarding:
##   1. Medusa and Leviathan guard on a fixed cadence and NEVER off it (the promotion itself).
##   2. The block beat is really out of the chance pool (total_weight dropped) rather than being
##      both conditional AND weighted, which would silently double its frequency.
##   3. The Dicelord's theft still wins every collision with the new guard cadence - the whole
##      reason Leviathan uses `% 4 == 2` instead of Medusa's `% 4 == 3`.
##   4. Measured DPT, so the "near-parity" claim in the doc is a number and not a hope.
##   5. Ink Tide never repeats (2026-09-07), so the 28/28 back-to-back cannot come back.
##
## Run:
##   ./Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe --path . --headless \
##       res://debug_cadence_promotion.tscn
## (headless is fine here - this is pure logic, no pixels are saved.)

const MEDUSA_AI := preload("res://enemies/medusa/medusa_enemy_ai.tscn")
const LEVIATHAN_AI := preload("res://enemies/leviathan/leviathan_enemy_ai.tscn")

const TURNS := 24
## Enough that a weighted block (the old 4-of-15 pick) would appear on essentially every
## off-cadence turn: P(zero blocks in 80 draws at 26.7%) is about 1e-11.
const TRIALS := 80
## The boss is designed to end in 6-9 turns; spike claims are only meaningful inside that.
const FIGHT_WINDOW := 9

var _pass := 0
var _fail := 0
## Kept alive for the whole run: EnemyAction.enemy is statically typed as Enemy, so the picker
## needs a real one. Never added to the tree, so _ready() never fires and no @onready child
## lookup is attempted - is_performable() only ever reads last_action / last_action_count.
var _stub: Enemy


func _ready() -> void:
	_stub = Enemy.new()

	_log("=== CADENCE PROMOTION HARNESS ===")
	_test_medusa()
	_test_leviathan_act1()
	_test_leviathan_act2()
	_test_leviathan_repeat_cap()
	_test_collision_negative_control()
	_test_intent_icons()

	_log("")
	_log("RESULT: %d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		_log("!!! FAILURES PRESENT !!!")
	# Never entered the tree, so nothing else will ever reap it - free it by hand or Godot
	# reports a leaked Area2D RID at exit and buries the result line in noise.
	_stub.free()
	get_tree().quit(1 if _fail > 0 else 0)


# ---------------------------------------------------------------- infrastructure

func _log(msg: String) -> void:
	# Prefixed so the run can be grepped clear of enemy_action_picker.gd's stray
	# `print(Global.fight_turn)`, which fires on every single get_action() call.
	print("[cadence] %s" % msg)


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		_pass += 1
		_log("  PASS  %s" % label)
	else:
		_fail += 1
		_log("  FAIL  %s%s" % [label, ("  -> " + detail) if detail != "" else ""])


func _build(scene: PackedScene) -> Node:
	var picker := scene.instantiate()
	add_child(picker)  # _ready() -> setup_chances()
	picker.enemy = _stub  # _set_enemy propagates to every action node
	return picker


## Samples the picker TRIALS times on each turn and returns {turn: {action_id: count}}.
## last_action is cleared before each draw so the "not N times in a row" caps never fire -
## this measures the pick rule, not a specific fight's history.
func _sample(picker: Node) -> Dictionary:
	var out := {}
	for turn in TURNS:
		Global.fight_turn = turn
		var counts := {}
		for _i in TRIALS:
			_stub.last_action = ""
			_stub.last_action_count = 0
			var action: EnemyAction = picker.get_action()
			var id: String = action.action_id
			counts[id] = int(counts.get(id, 0)) + 1
		out[turn] = counts
	return out


## Asserts `beat_id` is the ONLY thing that can happen on `expected_turns`, and can never happen
## on any other turn. Both halves matter: the first is the promotion, the second is proof the
## beat really left the weighted pool.
func _assert_cadence(label: String, samples: Dictionary, beat_id: String, expected_turns: Array) -> void:
	var wrong_turns: Array[int] = []
	var missed_turns: Array[int] = []
	for turn in TURNS:
		var counts: Dictionary = samples[turn]
		var hits := int(counts.get(beat_id, 0))
		if turn in expected_turns:
			if hits != TRIALS:
				missed_turns.append(turn)
		elif hits != 0:
			wrong_turns.append(turn)
	_check("%s fires on exactly %s" % [label, str(expected_turns)],
			missed_turns.is_empty(), "missing/partial on turns %s" % str(missed_turns))
	_check("%s never fires off-cadence" % label,
			wrong_turns.is_empty(), "leaked onto turns %s" % str(wrong_turns))


## Average damage per turn across the sampled window, block/no-damage beats counting as 0.
func _measure_dpt(picker: Node, samples: Dictionary) -> float:
	var damage_by_id := {}
	for action in picker.get_children():
		var dmg := 0
		# The attack scripts export `damage`; block/buff beats simply have no such property.
		if action.get("damage") != null:
			dmg = int(action.get("damage"))
		damage_by_id[action.action_id] = dmg

	var total := 0.0
	for turn in TURNS:
		for id in samples[turn]:
			total += float(damage_by_id.get(id, 0)) * float(samples[turn][id])
	return total / float(TURNS * TRIALS)


# ---------------------------------------------------------------- the tests

func _test_medusa() -> void:
	_log("")
	_log("-- Medusa (T2) : guard promoted to fight_turn %% 4 == 3 --")
	Global.current_act = 1
	var picker := _build(MEDUSA_AI)

	var block_node: EnemyAction = picker.get_node("BlockAction")
	_check("guard node is CONDITIONAL",
			block_node.type == EnemyAction.Type.CONDITIONAL,
			"type is %d" % block_node.type)
	# 5 (attack+Weak) + 6 (attack) = 11. It was 15 while the guard was still weighted, so this
	# is the direct check that the beat left the pool instead of being counted twice.
	_check("guard removed from the chance pool (total_weight 15 -> 11)",
			picker.total_weight == 11, "total_weight is %s" % str(picker.total_weight))

	var samples := _sample(picker)
	_assert_cadence("Medusa guard", samples, "medusa_block", [3, 7, 11, 15, 19, 23])
	_log("  measured DPT over %d turns: %.2f  (pre-promotion analytic: ~10.76)"
			% [TURNS, _measure_dpt(picker, samples)])
	picker.queue_free()


func _test_leviathan_act1() -> void:
	_log("")
	_log("-- Leviathan (act 1 boss) : guard promoted to fight_turn %% 4 == 2 --")
	Global.current_act = 1
	var picker := _build(LEVIATHAN_AI)

	var block_node: EnemyAction = picker.get_node("block_buff")
	_check("guard node is CONDITIONAL",
			block_node.type == EnemyAction.Type.CONDITIONAL,
			"type is %d" % block_node.type)
	_check("guard removed from the chance pool (total_weight 14 -> 10)",
			picker.total_weight == 10, "total_weight is %s" % str(picker.total_weight))
	# The picker's last-resort anti-freeze return is get_child(0); it must stay an act-1-safe
	# attack. If the theft node ever became child 0, an act-1 Leviathan could steal dice.
	var first: EnemyAction = picker.get_child(0)
	_check("child 0 is still a chance-based attack (anti-freeze fallback is act-1 safe)",
			first.type == EnemyAction.Type.CHANCE_BASED and first.action_id == "leviathan_ink_attack",
			"child 0 is %s" % first.action_id)

	var samples := _sample(picker)
	_assert_cadence("Leviathan guard", samples, "leviathan_block", [2, 6, 10, 14, 18, 22])
	_assert_cadence("Dice theft (act 1: must never fire)", samples, "dicelord_dice_theft", [])
	_log("  measured DPT over %d turns: %.2f  (pre-promotion analytic: ~12.83)"
			% [TURNS, _measure_dpt(picker, samples)])
	picker.queue_free()


func _test_leviathan_act2() -> void:
	_log("")
	_log("-- The Dicelord (act 2) : theft %% 3 == 1 must outrank the guard on collisions --")
	Global.current_act = 2
	var picker := _build(LEVIATHAN_AI)

	var theft_index := picker.get_node("dice_theft").get_index()
	var block_index := picker.get_node("block_buff").get_index()
	_check("dice_theft is ordered before block_buff (collisions resolve to theft)",
			theft_index < block_index,
			"theft at %d, block at %d" % [theft_index, block_index])

	var samples := _sample(picker)
	# % 3 == 1 within 0..23.
	_assert_cadence("Dice theft", samples, "dicelord_dice_theft", [1, 4, 7, 10, 13, 16, 19, 22])
	# % 4 == 2 minus the two turns theft takes over (10 and 22).
	_assert_cadence("Dicelord guard", samples, "leviathan_block", [2, 6, 14, 18])
	_log("  turns 10 and 22 are the only collisions in 0..23, and both resolve to theft.")
	_log("  first collision is turn 10 - outside the 6-9 turn boss target, which is why this")
	_log("  cadence is %% 4 == 2 and not Medusa's %% 4 == 3 (that would collide on turn 7).")
	picker.queue_free()


## Ink Tide must never fire twice in a row (2026-09-07). Unlike _sample(), this walks a REAL
## fight history - last_action / last_action_count are carried turn to turn exactly the way
## enemy.gd:840 maintains them - because the cap only exists in that history.
##
## Why the cap: the guard grants a PERMANENT +4 Muscle on turn 2, so from turn 3 a doubled Ink
## Tide read 28/28 = 56 raw against a 66 HP pool, and Ink stacks as DURATION so the second cast
## also EXTENDED the hidden-Power window. Measured at ~25% of 6-8 turn fights before the fix.
##
## Muscle is MODELLED here (+4 per guard, added flat) rather than read off a live
## ModifierHandler: _stub is never in the tree, so its @onready modifier_handler child does not
## exist. That matches _bake_bonus_damage / MUSCLE_STATUS being flat DMG_DEALT values.
func _test_leviathan_repeat_cap() -> void:
	_log("")
	_log("-- Leviathan repeat cap : Ink Tide never twice in a row --")
	Global.current_act = 1
	var picker := _build(LEVIATHAN_AI)

	var ink_doubles := 0
	var weak_doubles := 0
	var weak_triples := 0
	var fallback_hits := 0
	var worst_pair := 0
	var worst_single := 0

	for _trial in TRIALS:
		# Fresh fight: enemy.gd resets these per battle, so the walk must too.
		_stub.last_action = ""
		_stub.last_action_count = 0
		var muscle := 0
		var prev_id := ""
		var prev_dmg := 0
		for turn in TURNS:
			Global.fight_turn = turn
			var action: EnemyAction = picker.get_action()
			var id: String = action.action_id

			# The picker's blind last-resort `return get_child(0)` bypasses is_performable().
			# If both chance beats were ever capped on the same turn it would fire and quietly
			# re-open the double. They cap on mutually exclusive histories, so it must stay
			# unreachable - assert that rather than trust it.
			if not action.is_performable():
				fallback_hits += 1

			var dmg := 0
			if action.get("damage") != null:
				dmg = int(action.get("damage")) + muscle

			if id == prev_id:
				if id == "leviathan_ink_attack":
					ink_doubles += 1
				elif id == "leviathan_weak_attack":
					weak_doubles += 1
					if _stub.last_action_count >= 2:
						weak_triples += 1
			# Only inside the 6-9 turn boss target. Past it the Muscle ramp dominates and the
			# worst pair just reports "a 24-turn fight stacked 5 guards", which says nothing
			# about the spike this cap exists to remove.
			if turn < FIGHT_WINDOW and dmg > 0 and prev_dmg > 0:
				worst_pair = maxi(worst_pair, dmg + prev_dmg)
				worst_single = maxi(worst_single, dmg)

			# Mirror enemy.gd:840 exactly.
			if _stub.last_action == id:
				_stub.last_action_count += 1
			else:
				_stub.last_action = id
				_stub.last_action_count = 1
			if id == "leviathan_block":
				muscle += 4
			prev_id = id
			prev_dmg = dmg

	_check("Ink Tide never fires twice in a row",
			ink_doubles == 0, "%d consecutive Ink Tide pairs across %d fights" % [ink_doubles, TRIALS])
	_check("Crush never fires three times in a row (its own cap is intact)",
			weak_triples == 0, "%d triples" % weak_triples)
	_check("blind get_child(0) fallback is never reached",
			fallback_hits == 0, "%d picks bypassed is_performable()" % fallback_hits)

	# NEGATIVE CONTROL for the detector itself: Crush is still allowed to double, so the very
	# same counter must report doubles for it. If it reported zero for both beats the detector
	# would be inert and the Ink assertion above would be worthless.
	_check("NEGATIVE CONTROL: the same detector still sees Crush doubling",
			weak_doubles > 0, "no Crush doubles seen - the double-detector is inert")

	# Direct control of the cap itself, not just of the detector. Held one turn after an Ink
	# Tide, the picker must return Crush on EVERY draw; with the pre-fix `>= 2` it returned Ink
	# on ~40% of them (weight 4 of 10). A non-zero count here means the cap is not applying.
	Global.fight_turn = 3  # off the guard cadence, so a chance beat is picked
	var ink_after_ink := 0
	for _i in TRIALS:
		_stub.last_action = "leviathan_ink_attack"
		_stub.last_action_count = 1
		if picker.get_action().action_id == "leviathan_ink_attack":
			ink_after_ink += 1
	_check("CONTROL: held one turn after Ink Tide, %d/%d draws refuse to repeat it" % [TRIALS, TRIALS],
			ink_after_ink == 0, "%d draws repeated it (pre-fix this was ~40%%)" % ink_after_ink)

	_log("  worst two-consecutive-turn damage inside the %d-turn boss window: %d raw (single %d)"
			% [FIGHT_WINDOW, worst_pair, worst_single])
	_log("  (was 56 = 28+28 as early as turns 3 & 4; the single hit still ramps 24 -> 28 -> 32)")
	picker.queue_free()


## Negative control. A test that cannot fail proves nothing, so: put the guard back in front of
## the theft node and confirm the collision turns flip to the guard and the assertions go red.
func _test_collision_negative_control() -> void:
	_log("")
	_log("-- NEGATIVE CONTROL : guard ordered before theft (the bug this ordering prevents) --")
	Global.current_act = 2
	var picker := _build(LEVIATHAN_AI)
	var block_node := picker.get_node("block_buff")
	picker.move_child(block_node, picker.get_node("dice_theft").get_index())

	Global.fight_turn = 10
	_stub.last_action = ""
	_stub.last_action_count = 0
	var action: EnemyAction = picker.get_action()
	_check("with the guard ordered first, turn 10 loses the theft (control detects it)",
			action.action_id == "leviathan_block",
			"got %s - the control did not reproduce, so the ordering assertion may be inert"
					% action.action_id)
	_log("  i.e. the shipped ordering is load-bearing, not incidental.")
	picker.queue_free()


func _test_intent_icons() -> void:
	_log("")
	_log("-- Intent honesty : a beat that grants Muscle must not telegraph as plain block --")
	# Since the STS2-style rider slot (2026-08-14), the combined buff_block artwork is
	# retired: the guard telegraphs as block icon (primary, carries the number) + buff icon
	# (rider in icon2). Asserting BOTH halves - losing either one silently recreates the
	# "ramp is invisible on the beat that produces it" bug this test exists for.
	Global.current_act = 1
	for entry in [[MEDUSA_AI, "BlockAction", "Medusa"], [LEVIATHAN_AI, "block_buff", "Leviathan"]]:
		var picker := _build(entry[0])
		var action: EnemyAction = picker.get_node(entry[1])
		var icon_path := ""
		var rider_path := ""
		if action.intent and action.intent.icon:
			icon_path = action.intent.icon.resource_path
		if action.intent and action.intent.icon2:
			rider_path = action.intent.icon2.resource_path
		_check("%s guard leads with the block icon" % entry[2],
				icon_path.ends_with("block_icon_intent.png"), "icon is '%s'" % icon_path)
		_check("%s guard carries the buff rider (STS2 pair)" % entry[2],
				rider_path.ends_with("buff_icon_intent.png"), "icon2 is '%s'" % rider_path)
		picker.queue_free()
