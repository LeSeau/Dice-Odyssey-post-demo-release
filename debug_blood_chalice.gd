extends Node

# Julien, 2026-09-09: "have blood chalice relic but attacks deal damage like the foe is already
# exposed when it wasn't. 38 damage becomes 57 AND exposed1. However it should deal damage, and
# THEN apply exposed."
#
# Root cause: the relic listened to Events.card_played, which Card.play() emits on its FIRST
# line - before apply_effects(). So Exposed was already on the enemy when the card's own
# DamageEffect ran, and take_damage's DMG_TAKEN pass gave that very hit the +50% (38 * 1.5 =
# 57, exactly what he saw).
#
# Fix: the relic still DECIDES on card_played (that is the only window where
# Global.playing_red_card is true), but APPLIES on the new Events.card_damage_resolved.
#
# The deferred path is the half a naive fix would miss: a big single-target attack hands its
# hit to the held-die strike, which flies ~0.26s before resolving. Applying Exposed "right
# after apply_effects()" would STILL beat that hit - and 38 damage is comfortably inside strike
# range, so Julien's exact case is the deferred one. Section C pins it.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_blood_chalice.tscn --headless

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
const STRIKE_CARD := "res://characters/warrior/cards/warrior_axe_attack1.tres"
const BLOCK_CARD := "res://characters/warrior/cards/warrior_block1.tres"
const BLOOD_CHALICE := "res://relics/blood_chalice.tres"
const EXPOSED_STATUS := preload("res://statuses/exposed.tres")

# Well below Shaker's STRONG rung (15) so the hit resolves synchronously, and well below the
# padded enemy HP so it is never lethal - either would hand the hit to the die strike.
const SMALL_POWER := 10
# Above the STRONG rung, so the strike takes it. Julien's real case.
const BIG_POWER := 20
const PADDED_HP := 400

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _hand: Hand
var _relic_handler: RelicHandler


func _ready() -> void:
	Global.tutorial_on = false
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)

	await _boot_battle()
	await _scenario_instant_path()
	await _scenario_next_hit_benefits()
	await _scenario_deferred_strike_path()
	await _scenario_self_targeted_card()
	await _scenario_negative_control()

	print("\n==== BLOOD CHALICE ORDER: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


func _check(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("[chalice] PASS  ", name, "  ", detail)
	else:
		fails += 1
		print("[chalice] FAIL  ", name, "  ", detail)


func _await_until(cond: Callable, timeout_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _boot_battle() -> void:
	Global.reset_run_state()
	Global.tutorial_on = false
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)

	_relic_handler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(_relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	# Dice Pillar ships in the starter deck and pays Surge +1 per roll WHILE HELD; it never
	# touches damage here, but the same class of in-hand passive is what made an earlier
	# harness report different numbers run to run. Stripped so nothing can drift.
	var clean: Array[Card] = []
	for c: Card in _battle.char_stats.deck.cards:
		if not c.id.begins_with("card_dead_weight"):
			clean.append(c)
	_battle.char_stats.deck.cards = clean

	_battle.relics = _relic_handler
	_battle.battle_stats = load(FIGHT)
	_battle.act_tier = 1
	_relic_handler.add_relic(load(BLOOD_CHALICE))

	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 20.0)
	_hand = _battle.find_child("Hand", true, false) as Hand

	var alive := _enemies()
	_check("battle booted with 3 enemies", _hand != null and alive.size() >= 3,
			"enemies=%d" % alive.size())
	# Padded so no test hit is ever lethal: a lethal hit qualifies for the die strike at ANY
	# size, which would quietly turn the "instant path" sections into deferred ones.
	for e in alive:
		e.stats.max_health = PADDED_HP
		e.stats.health = PADDED_HP
		e.stats.block = 0
	_check("Blood Chalice equipped", _relic_handler._get_all_relic_ui_nodes().size() == 1)
	_check("Red is not infused (no Berserker x1.5 in play)", not Global.is_dice_infused("red"))


func _enemies() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n) and n is Enemy:
			out.append(n)
	return out


func _is_exposed(node: Node) -> bool:
	var handler = node.status_handler
	if handler == null:
		return false
	return handler._has_status("exposed")


# Plays `card_path` at `power` straight through Card.play(), with the Red-socket scope open.
# The real socket path (dice.gd -> card_ui._on_red_dice_rolled -> forced AIMING -> release)
# ends in exactly this call with exactly these globals set; driving the UI state machine
# headless would test the aim widget, not the ordering this harness is about.
func _play_on_red(card_path: String, power: int, targets: Array[Node]) -> void:
	var card: Card = (load(card_path) as Card).duplicate()
	Global.dice_type = "red"
	Global.roll_value = power
	Global.roll_history = [power]
	Global.playing_red_card = true
	card.play(targets, _battle.char_stats, Global.player.modifier_handler)
	Global.playing_red_card = false


func _play_on_blue(power: int, targets: Array[Node]) -> void:
	var card: Card = (load(STRIKE_CARD) as Card).duplicate()
	Global.dice_type = "blue"
	Global.roll_value = power
	Global.roll_history = [power]
	card.play(targets, _battle.char_stats, Global.player.modifier_handler)


# A) The reported shape, on the synchronous path. The hit that EARNS the debuff must not be
# the hit that PAYS it.
func _scenario_instant_path() -> void:
	print("\n-- A. Small Red-socketed Strike: damage first, Exposed after --")
	var enemy: Node = _enemies()[0]
	_check("enemy starts clean (no Exposed)", not _is_exposed(enemy))
	var before: int = enemy.stats.health
	var frame := Engine.get_process_frames()
	var targets: Array[Node] = [enemy]
	_play_on_red(STRIKE_CARD, SMALL_POWER, targets)
	await _settle(0.1)
	var dealt: int = before - int(enemy.stats.health)
	_check("no die strike took this hit (instant path)", Global.die_strike_frame != frame,
			"strike_frame=%d play_frame=%d" % [Global.die_strike_frame, frame])
	_check("hit is UNBOOSTED: %d damage, not %d" % [SMALL_POWER, int(SMALL_POWER * 1.5)],
			dealt == SMALL_POWER, "dealt=%d" % dealt)
	_check("Exposed landed after the hit", _is_exposed(enemy))


# B) The other half of the contract: the debuff has to actually work on what comes next,
# otherwise "apply it later" would just be a nerf to nothing.
func _scenario_next_hit_benefits() -> void:
	print("\n-- B. The NEXT hit does get the +50% --")
	var enemy: Node = _enemies()[0]
	_check("enemy still Exposed from section A", _is_exposed(enemy))
	var before: int = enemy.stats.health
	var targets: Array[Node] = [enemy]
	_play_on_blue(SMALL_POWER, targets)
	await _settle(0.1)
	var dealt: int = before - int(enemy.stats.health)
	_check("follow-up hit is boosted to %d" % int(SMALL_POWER * 1.5),
			dealt == int(SMALL_POWER * 1.5), "dealt=%d" % dealt)


# C) THE ONE THAT MATTERS FOR 38 -> 57. A hit this size is handed to the held-die strike and
# lands ~0.26s later, so a fix that merely moved the debuff after apply_effects() would still
# be wrong here.
func _scenario_deferred_strike_path() -> void:
	print("\n-- C. Big Red-socketed Strike: the hit is deferred to the die strike --")
	var enemy: Node = _enemies()[1]
	_check("second enemy starts clean", not _is_exposed(enemy))
	var before: int = enemy.stats.health
	var frame := Engine.get_process_frames()
	var targets: Array[Node] = [enemy]
	_play_on_red(STRIKE_CARD, BIG_POWER, targets)
	var struck := Global.die_strike_frame == frame
	_check("the die strike DID take this hit (deferred path under test)", struck,
			"strike_frame=%d play_frame=%d" % [Global.die_strike_frame, frame])
	# Nothing should have happened yet - the die is still in the air.
	if struck:
		var immediate: int = before - int(enemy.stats.health)
		_check("no damage yet while the die flies", immediate == 0, "dealt=%d" % immediate)
		_check("no Exposed yet either", not _is_exposed(enemy))
	await _await_until(func() -> bool: return int(enemy.stats.health) < before, 3.0)
	await _settle(0.3)
	var dealt: int = before - int(enemy.stats.health)
	_check("deferred hit is UNBOOSTED: %d damage, not %d" % [BIG_POWER, int(BIG_POWER * 1.5)],
			dealt == BIG_POWER, "dealt=%d" % dealt)
	_check("Exposed landed after the deferred hit", _is_exposed(enemy))


# D) A Red-socketed card that targets the player must not Exposed the player, and must not
# leave a pending debuff sitting around for the next card to fire.
func _scenario_self_targeted_card() -> void:
	print("\n-- D. Block socketed on Red: nothing to expose --")
	var player := Global.player
	var self_targets: Array[Node] = [player]
	_play_on_red(BLOCK_CARD, SMALL_POWER, self_targets)
	await _settle(0.1)
	_check("player did not get Exposed", not _is_exposed(player))
	var enemy: Node = _enemies()[2]
	var before: int = enemy.stats.health
	# A plain Blue attack right after: if D left something pending, this is where it would
	# land on the wrong card.
	var targets: Array[Node] = [enemy]
	_play_on_blue(SMALL_POWER, targets)
	await _settle(0.1)
	var dealt: int = before - int(enemy.stats.health)
	_check("third enemy not Exposed by the Block play", not _is_exposed(enemy))
	_check("its hit is unboosted (%d)" % SMALL_POWER, dealt == SMALL_POWER, "dealt=%d" % dealt)


# E) NEGATIVE CONTROL. Re-create the old behaviour (apply Exposed straight off card_played)
# with the relic removed, and confirm sections A/C would have caught it. A test that cannot
# fail proves nothing.
func _scenario_negative_control() -> void:
	print("\n-- E. Negative control: the OLD ordering, reproduced --")
	# There is no remove_relic(): the handler deactivates on child_exiting_tree, so freeing
	# the RelicUI is how a relic is taken off in this codebase.
	for relic_ui in _relic_handler._get_all_relic_ui_nodes():
		relic_ui.queue_free()
	await _settle(0.3)
	_check("relic removed for the control",
			_relic_handler._get_all_relic_ui_nodes().is_empty())

	Events.card_played.connect(_legacy_on_card_played)

	var enemy: Node = _enemies()[2]
	var before: int = enemy.stats.health
	var targets: Array[Node] = [enemy]
	_play_on_red(STRIKE_CARD, SMALL_POWER, targets)
	await _settle(0.1)
	var dealt: int = before - int(enemy.stats.health)
	# This is the BUG being reproduced, so the PASS condition is that it still bites.
	_check("old ordering still inflates its own hit (%d -> %d)"
			% [SMALL_POWER, int(SMALL_POWER * 1.5)],
			dealt == int(SMALL_POWER * 1.5),
			"dealt=%d (if this is %d, the harness cannot see the bug)" % [dealt, SMALL_POWER])

	Events.card_played.disconnect(_legacy_on_card_played)


func _legacy_on_card_played(_card: Card) -> void:
	if not Global.playing_red_card:
		return
	var enemies: Array[Node] = []
	for candidate in Global.last_played_card_targets:
		if is_instance_valid(candidate) and candidate is Enemy:
			enemies.append(candidate)
	if enemies.is_empty():
		return
	var status_effect := StatusEffect.new()
	var exposed: Status = EXPOSED_STATUS.duplicate()
	exposed.duration = 1
	status_effect.status = exposed
	status_effect.execute(enemies)
