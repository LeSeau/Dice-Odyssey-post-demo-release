extends Node

# Regression harness for the TIER-0 ENEMY REWORK (2026-09-01).
#
# Pins the behaviour rules the rework is made of, not its feel:
#   - Skeleton runs a fixed strike / bone guard / bone spike cycle, forever, no randomness
#   - Satyr S: screech never twice in a row, gore never three times in a row
#   - Satyr B: guaranteed turn-1 screech, both beats capped at 2 in a row
#   - Kraken S: ink never twice in a row, attack capped at 2 - and repeats DO happen now
#     (this used to be a forced A-B-A-B metronome, so "a repeat is possible" is the change)
#   - Kraken B: guaranteed turn-1 ink and turn-2 crush, then ink capped at 1 / crush at 2
#   - Dice Mimic: steal on turn 1, then a flat bite every turn (no guard beat)
#   - the picker's blind `get_child(0)` fallback is never reached by any of them
#   - forced_opener_action_id pins each Slanderer to a different opening beat
#   - the Dice Mimic hostage survives a refill, comes back only when the mimic DIES, and is
#     fight-scoped
#
# Sections A-H simulate turns directly (pick an action, replicate Enemy.do_turn()'s
# last_action bookkeeping, never run the tweens), which is what makes a 400-turn cap check
# cheap. Section I boots a REAL battle.tscn through start_battle() - the hostage lives in
# dice_interface's refill, so simulating it would prove nothing.
#
# NEGATIVE CONTROL (house rule - a check that cannot fail proves nothing):
#   run with T0_NEGATIVE=1 to disable the caps and the fixed cycle at the source, and the
#   corresponding checks must go red. See _negative_control_note() at the bottom.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_t0_patterns.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT_SKELETON := "res://battles/tier_0_crab.tscn"
const FIGHT_SATYRS := "res://battles/tier_0_satyrs_3.tscn"
const FIGHT_KRAKENS := "res://battles/tier_0_octopus_3.tscn"
# The Mimic moved to tier 1 on 2026-09-02 and pairs with a Goblin: the fight-mate has to
# outlive it, or "kill it and get your die back" just ends the fight instead of changing it.
const FIGHT_MIMIC_SCENE := "res://battles/tier_1_dice_mimic.tscn"
const FIGHT_MIMIC := "res://battles/tier_1_dice_mimic.tres"
# The only remaining user of forced_opener_action_id (the Mimic's Satyr is gone with the
# tier-0 encounter, and a Goblin's cycle is fixed, so pinning one would prove nothing).
const FIGHT_SLANDERERS := "res://battles/tier_1_slanderers.tscn"

const LONG_RUN := 400
const OPENER_TRIALS := 60

var checks := 0
var fails := 0
var fallback_hits := 0
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

	_section_skeleton()
	_section_satyr_small()
	_section_satyr_big()
	_section_kraken_small()
	_section_kraken_big()
	_section_mimic_cycle()
	_section_forced_opener()
	_section_fallback()

	await _section_hostage()

	print("\n==== T0 PATTERNS: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- simulation helpers

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


# Picks `turns` actions in a row, replicating the last_action / last_action_count bookkeeping
# that Enemy.do_turn() does at enemy.gd:822-826. Returns the sequence of action_ids.
func _simulate(enemy: Enemy, turns: int, start_turn := 0) -> Array[String]:
	var seq: Array[String] = []
	enemy.last_action = ""
	enemy.last_action_count = 0
	for t in range(turns):
		Global.fight_turn = start_turn + t
		enemy.update_action()
		var action: EnemyAction = enemy.current_action
		if action == null:
			seq.append("<null>")
			continue
		# The picker's last-resort `return get_child(0)` skips both the type check and
		# is_performable(), so an action arriving here unperformable IS the fallback firing.
		if not action.is_performable():
			fallback_hits += 1
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


# ---------------------------------------------------------------- A: Skeleton

func _section_skeleton() -> void:
	print("\n--- A: Skeleton runs a fixed 3-beat cycle ---")
	var fight := _load_fight(FIGHT_SKELETON)
	var skeleton := _enemy_named(fight, "crab")
	if skeleton == null:
		check("skeleton found in tier_0_crab", false)
		return

	var seq := _simulate(skeleton, 12)
	var expected: Array[String] = []
	for i in range(4):
		expected.append_array(["crab_attack", "crab_block", "crab_spike_attack"])
	check("12 turns are strike/guard/spike repeating", seq == expected, ", ".join(seq))

	# The spike moved from every 4th turn to every 3rd, and it is the beat the fight is
	# built around - pin the turn it lands on, not just that it exists.
	check("spike lands on player turns 3, 6, 9, 12",
			seq[2] == "crab_spike_attack" and seq[5] == "crab_spike_attack"
			and seq[8] == "crab_spike_attack" and seq[11] == "crab_spike_attack")
	check("no randomness: a second run is identical", _simulate(skeleton, 12) == seq)

	# The one-shot forced opener (Global.tutorial_enemy_attack) is gone: turn 1 is a plain
	# strike, and there is no longer a "first crab fight of the run" special case.
	check("turn 1 is the ordinary strike", seq[0] == "crab_attack")
	fight.queue_free()


# ---------------------------------------------------------------- B: Satyr S

func _section_satyr_small() -> void:
	print("\n--- B: Satyr S caps (screech 1, gore 2) ---")
	var fight := _load_fight(FIGHT_SATYRS)
	var satyr := _enemy_named(fight, "s satyr")
	if satyr == null:
		check("small satyr found in tier_0_satyrs_3", false)
		return

	var seq := _simulate(satyr, LONG_RUN)
	check("screech never twice in a row", _max_run(seq, "satyr_debuff") <= 1,
			"max run %d" % _max_run(seq, "satyr_debuff"))
	check("gore never three times in a row", _max_run(seq, "satyr_attack") <= 2,
			"max run %d" % _max_run(seq, "satyr_attack"))
	# Both beats must stay reachable - a cap that accidentally locks a beat out entirely
	# would still satisfy the two checks above.
	check("both beats still occur", _count(seq, "satyr_debuff") > 0 and _count(seq, "satyr_attack") > 0,
			"screech %d / gore %d" % [_count(seq, "satyr_debuff"), _count(seq, "satyr_attack")])
	check("no deadlock: every turn produced an action", not seq.has("<null>"))
	fight.queue_free()


# ---------------------------------------------------------------- C: Satyr B

func _section_satyr_big() -> void:
	print("\n--- C: Satyr B opener + caps ---")
	var fight := _load_fight(FIGHT_SATYRS)
	var satyr := _enemy_named(fight, "b satyr")
	if satyr == null:
		check("bigger satyr found in tier_0_satyrs_3", false)
		return

	var openers := 0
	for i in range(OPENER_TRIALS):
		var one := _simulate(satyr, 1)
		if one[0] == "bigger_satyr_attack_debuff":
			openers += 1
	check("turn 1 is ALWAYS the screech opener", openers == OPENER_TRIALS,
			"%d/%d" % [openers, OPENER_TRIALS])

	var seq := _simulate(satyr, LONG_RUN)
	check("screech capped at 2 in a row", _max_run(seq, "bigger_satyr_attack_debuff") <= 2,
			"max run %d" % _max_run(seq, "bigger_satyr_attack_debuff"))
	check("gore capped at 2 in a row", _max_run(seq, "bigger_satyr_attack") <= 2,
			"max run %d" % _max_run(seq, "bigger_satyr_attack"))
	# The gore beat had NO action_id before this pass, so its cap could never have tracked.
	check("gore beat has a trackable action_id", _count(seq, "bigger_satyr_attack") > 0,
			"%d gores" % _count(seq, "bigger_satyr_attack"))
	fight.queue_free()


# ---------------------------------------------------------------- D: Kraken S

func _section_kraken_small() -> void:
	print("\n--- D: Kraken S caps (ink 1, attack 2) ---")
	var fight := _load_fight(FIGHT_KRAKENS)
	var kraken := _enemy_named(fight, "s octopus")
	if kraken == null:
		check("small kraken found in tier_0_octopus_3", false)
		return

	var seq := _simulate(kraken, LONG_RUN)
	check("ink never twice in a row", _max_run(seq, "octopus_debuff_attack") <= 1,
			"max run %d" % _max_run(seq, "octopus_debuff_attack"))
	check("attack never three times in a row", _max_run(seq, "octopus_attack") <= 2,
			"max run %d" % _max_run(seq, "octopus_attack"))
	# THE change on this enemy: it used to be a forced A-B-A-B metronome (both beats hard
	# checked `last_action != self`), so a repeated attack was impossible. If this goes red
	# the old alternation lock is back.
	check("attack CAN now repeat (was a forced metronome)",
			_max_run(seq, "octopus_attack") == 2,
			"max run %d" % _max_run(seq, "octopus_attack"))
	fight.queue_free()


# ---------------------------------------------------------------- E: Kraken B

func _section_kraken_big() -> void:
	print("\n--- E: Kraken B openers + caps ---")
	var fight := _load_fight(FIGHT_KRAKENS)
	var kraken := _enemy_named(fight, "b octopus")
	if kraken == null:
		check("bigger kraken found in tier_0_octopus_3", false)
		return

	var ink_openers := 0
	var crush_seconds := 0
	for i in range(OPENER_TRIALS):
		var two := _simulate(kraken, 2)
		if two[0] == "bigger_octopus_attack_debuff":
			ink_openers += 1
		if two[1] == "bigger_octopus_attack":
			crush_seconds += 1
	check("turn 1 is ALWAYS the ink blast", ink_openers == OPENER_TRIALS,
			"%d/%d" % [ink_openers, OPENER_TRIALS])
	check("turn 2 is ALWAYS the crush", crush_seconds == OPENER_TRIALS,
			"%d/%d" % [crush_seconds, OPENER_TRIALS])

	var seq := _simulate(kraken, LONG_RUN)
	# Ink is a DURATION status: re-applying EXTENDS the blackout on the Power number, so a
	# cap of 2 here would mean roughly four straight blind turns on floors 1-3.
	check("ink never twice in a row", _max_run(seq, "bigger_octopus_attack_debuff") <= 1,
			"max run %d" % _max_run(seq, "bigger_octopus_attack_debuff"))
	check("crush capped at 2 in a row", _max_run(seq, "bigger_octopus_attack") <= 2,
			"max run %d" % _max_run(seq, "bigger_octopus_attack"))
	check("crush CAN now repeat (was locked to post-ink only)",
			_max_run(seq, "bigger_octopus_attack") == 2,
			"max run %d" % _max_run(seq, "bigger_octopus_attack"))
	fight.queue_free()


# ---------------------------------------------------------------- F: Mimic cycle

func _section_mimic_cycle() -> void:
	print("\n--- F: Dice Mimic beat cycle ---")
	var fight := _load_fight(FIGHT_MIMIC_SCENE)
	var mimic := _enemy_named(fight, "mimic")
	if mimic == null:
		check("mimic found in tier_0_dice_mimic", false)
		return

	var seq := _simulate(mimic, 9)
	var expected: Array[String] = [
		"mimic_steal", "mimic_attack", "mimic_attack",
		"mimic_attack", "mimic_attack", "mimic_attack",
		"mimic_attack", "mimic_attack", "mimic_attack",
	]
	check("steal on turn 1, then a flat bite forever", seq == expected, ", ".join(seq))
	check("the steal happens exactly once", _count(seq, "mimic_steal") == 1)
	# The guard beat (block 5 + 2 Str) was cut with the tier-1 move: the Goblin is the clock
	# now, and one clock per fight.
	check("no guard beat survives", _count(seq, "mimic_guard") == 0)
	check("no randomness: a second run is identical", _simulate(mimic, 9) == seq)
	fight.queue_free()


# ---------------------------------------------------------------- G: forced opener

func _section_forced_opener() -> void:
	print("\n--- G: forced_opener_action_id ---")
	var fight := _load_fight(FIGHT_SLANDERERS)
	var slanderer := _enemy_named(fight, "slanderer a")
	if slanderer == null:
		check("slanderer A found in the pair encounter", false)
		return

	check("the encounter sets the override",
			slanderer.forced_opener_action_id == "slanderer_whisper",
			slanderer.forced_opener_action_id)

	var plain := 0
	for i in range(OPENER_TRIALS):
		var one := _simulate(slanderer, 1)
		if one[0] == "slanderer_whisper":
			plain += 1
	# Without the override this body is a flat coin flip, so ~half of these would sneer.
	check("its turn 1 is ALWAYS the pinned beat", plain == OPENER_TRIALS,
			"%d/%d" % [plain, OPENER_TRIALS])

	# And the override must be turn-1 only, not a permanent lock on the beat.
	var seq := _simulate(slanderer, LONG_RUN)
	check("later turns are free to sneer again", _count(seq, "slanderer_sneer") > 0,
			"%d sneers" % _count(seq, "slanderer_sneer"))

	# Every other enemy must be untouched by the new field.
	var other := _load_fight(FIGHT_SATYRS)
	var untouched := _enemy_named(other, "s satyr")
	check("enemies without the override are unaffected",
			untouched != null and untouched.forced_opener_action_id == "")
	other.queue_free()
	fight.queue_free()


# ---------------------------------------------------------------- H: fallback

func _section_fallback() -> void:
	print("\n--- H: the blind get_child(0) fallback ---")
	# Accumulated across every simulated turn in sections A-G. The fallback returns child 0
	# without checking is_performable(), so any unperformable action reaching a turn means a
	# beat set stopped being a total partition (or two caps deadlocked each other).
	check("no enemy ever fell through to the blind fallback", fallback_hits == 0,
			"%d hit(s)" % fallback_hits)


# ---------------------------------------------------------------- I: hostage (real battle)

func _section_hostage() -> void:
	print("\n--- I: Dice Mimic hostage, in a real battle ---")
	# Deliberately dirty. start_battle() used to call reset_enemy_actions() BEFORE zeroing
	# fight_turn, so every enemy's opener was picked against whatever the previous fight left
	# behind. Harmless while only the crab spike cared; fatal now that the Skeleton cycle and
	# this steal are fight_turn-gated. Sections A-H leave fight_turn high, which is exactly
	# the state that exposed it.
	Global.fight_turn = 99
	await _boot_battle()

	var mimic := _find_mimic()
	if mimic == null:
		check("mimic present in the booted battle", false)
		return

	check("a stale fight_turn does not leak into the opener",
			mimic.current_action != null and mimic.current_action.action_id == "mimic_steal",
			"none" if mimic.current_action == null else mimic.current_action.action_id)
	check("hostage list starts empty", Global.dice_hostage_types.is_empty())

	# One real turn boundary: the mimic's turn-1 action resolves for real, tweens and all.
	await _turn_boundary()

	check("the mimic took exactly one die hostage", Global.dice_hostage_types.size() == 1,
			str(Global.dice_hostage_types))
	if Global.dice_hostage_types.is_empty():
		return
	var stolen: String = Global.dice_hostage_types[0]
	check("it stole a type the player actually owns",
			int(Global.get(stolen + "_dice_max_amount")) > 0, stolen)

	# THE trap this design is built around: dice_interface's refill recomputes every count from
	# max + bonus and zeroes the bonus fields in the same function, so a hostage implemented as
	# a negative bonus would silently hand the die back right here.
	#
	# Measured against each type's MAX, not against the turn-1 counts: Dice Bag legitimately
	# adds a Blue on turn 1 only, so a turn-1-vs-turn-2 comparison would false-fail the moment
	# the mimic happened to steal Blue.
	var short_ok := false
	var others_ok := true
	var detail := ""
	for type: String in _dice_counts():
		var maximum: int = int(Global.get(type + "_dice_max_amount"))
		var current: int = int(Global.get(type + "_dice_current_amount"))
		if type == stolen:
			short_ok = current == maxi(0, maximum - 1)
			detail = "%s: %d of max %d" % [type, current, maximum]
		elif current != maximum:
			others_ok = false
	check("the stolen die is STILL missing after the refill", short_ok, detail)
	check("no other dice type was touched", others_ok)

	# The half-health ransom was cut on 2026-09-02: only death releases the die now. Hurting
	# it badly must therefore change nothing at all.
	var before_return: int = int(Global.get(stolen + "_dice_current_amount"))
	mimic.take_damage(10, Modifier.Type.DMG_DEALT)
	await get_tree().process_frame
	check("half health does NOT return the die any more",
			Global.dice_hostage_types.size() == 1, str(Global.dice_hostage_types))
	check("and the die is still missing from the pool",
			int(Global.get(stolen + "_dice_current_amount")) == before_return,
			"%d" % int(Global.get(stolen + "_dice_current_amount")))

	# Killing it hands the die back, usable the same turn. The Goblin is still alive, so this
	# is a mid-fight rescue rather than the end of the fight - which is the whole point of the
	# tier-1 pairing.
	mimic.take_damage(mimic.stats.health + 5, Modifier.Type.DMG_DEALT)
	await get_tree().process_frame
	check("killing it returns the die immediately",
			int(Global.get(stolen + "_dice_current_amount")) == before_return + 1,
			"%d -> %d" % [before_return, int(Global.get(stolen + "_dice_current_amount"))])
	check("the hostage list is empty again", Global.dice_hostage_types.is_empty(),
			str(Global.dice_hostage_types))
	# House rule: a check that cannot fail proves nothing. Counting the group would pass even
	# if the mimic were the only thing in it, so look for a body that is NOT the mimic.
	var mate_alive := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other != null and other != mimic and other.stats != null and other.stats.health > 0:
			mate_alive = true
	check("the fight-mate outlives the mimic, so the rescue is mid-fight", mate_alive)

	# Fight-scoped safety net: even if a return hook ever misfired, the next fight is whole.
	Global.dice_hostage_types = ["blue"]
	_battle.start_battle()
	await _await_until(func() -> bool: return true, 1.0)
	check("start_battle() clears any leftover hostage", Global.dice_hostage_types.is_empty(),
			str(Global.dice_hostage_types))


func _dice_counts() -> Dictionary:
	var out := {}
	for type: String in ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]:
		out[type] = int(Global.get(type + "_dice_current_amount"))
	return out


func _find_mimic() -> Enemy:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.stats != null and enemy.stats.enemy_name == "Dice Mimic":
			return enemy
	return null


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
	_battle.battle_stats = load(FIGHT_MIMIC)
	_battle.act_tier = 0
	# Documented harness trap: without the starting relic (Dice Bag) turn 1 hands out fewer
	# Blue dice than the real game, which has bitten a previous harness.
	relic_handler.add_relic(warrior.starting_relic)

	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 15.0)


# One full turn: the enemies actually take their actions, unlike emitting
# player_turn_started directly.
func _turn_boundary() -> void:
	var before := hands_drawn
	Events.player_turn_ended.emit()
	await _await_until(func() -> bool: return hands_drawn > before, 20.0)


func _await_until(cond: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


# NEGATIVE CONTROL, for whoever touches this next. To prove these checks can fail:
#   1. Skeleton: put `return true` back at the top of crab_attack_action.is_performable()
#      and restore `type = 1` / chance_weight on the three nodes -> section A goes red.
#   2. Caps: make EnemyAction.hit_consecutive_cap() `return false` -> sections B/C/D/E go red
#      on the max-run checks.
#   3. Openers: delete the `opener_turn` branch from bigger_octopus_attack*.gd -> E's
#      turn-1/turn-2 checks go red.
#   4. Forced opener: clear forced_opener_action_id on Slanderer A -> G's 100% check lands
#      near 50%.
#   5. Hostage: move the deduction from dice_interface's refill onto <type>_dice_bonus_amount
#      -> I's "STILL missing after the refill" check goes red, which is the whole point of it.
#   6. Ransom: put a half-health release back in dice_hostage.gd -> I's "half health does NOT
#      return the die" check goes red.
