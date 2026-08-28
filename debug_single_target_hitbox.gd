extends Node

# Verification harness for the 2026-08-28 pass:
#   A. SINGLE-TARGET COLLAPSE - a SINGLE_ENEMY card must resolve against exactly one enemy even
#      when two of them sit in `targets` at once (which happens for real whenever two bodies
#      stand close enough for their fixed-size hitboxes to overlap under the cursor).
#   B. Trebuchet buffed to +3 / +4 thrown-dice damage.
#   C. Sixth Gear retuned to "every 8 dice, gain 6 Power".
#
# Boots a REAL battle.tscn (same recipe as debug_relic_batch.gd) so cards go through the real
# Card.play() -> DamageEffect -> Enemy.take_damage path, not a simulation of it.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_single_target_hitbox.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"

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


func _section(title: String) -> void:
	print("\n--- ", title, " ---")


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	# Suppress achievement toasts: the fake plays below would otherwise unlock things.
	Global.tutorial_on = true
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)

	await _boot_battle()
	await _scenario_single_target()
	await _scenario_trebuchet()
	await _scenario_sixth_gear()
	await _scenario_aim_highlight()

	print("\n==== SINGLE TARGET / BALANCE: %d checks, %d fail(s) ====" % [checks, fails])
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
	check("battle booted", _player != null)
	check("fight has at least two enemies", _enemies().size() >= 2, str(_enemies().size()))


# ------------------------------------------------------- A. single-target collapse
func _scenario_single_target() -> void:
	_section("A. SINGLE-TARGET COLLAPSE")

	var enemies := _enemies()
	if enemies.size() < 2:
		check("need two enemies for the overlap scenario", false)
		return
	var a: Node = enemies[0]
	var b: Node = enemies[1]
	# These bodies have single-digit HP, and a dead enemy leaves the "enemies" group - which
	# would silently turn the later AoE check into "hit one enemy and one corpse". Fatten them
	# so every damage assertion below reads a real before/after delta.
	_fatten(a)
	_fatten(b)

	var strike := load("res://characters/warrior/cards/warrior_axe_attack1.tres") as Card
	check("Strike is single-targeted", strike.is_single_targeted())

	# A1 - the pick itself.
	var both: Array[Node] = [a, b]
	var picked := strike.pick_single_target(both)
	check("pick_single_target returns exactly one enemy", picked.size() == 1, str(picked.size()))
	check("picked enemy is one of the candidates", picked.size() == 1 and both.has(picked[0]))

	# A2 - order independence. If the rule were "whichever body entered the aim probe first
	# wins", reversing the array would flip the answer; nearest-to-cursor cannot.
	var reversed_order: Array[Node] = [b, a]
	var picked_reversed := strike.pick_single_target(reversed_order)
	check("pick is order-independent (not just targets[0])",
			picked.size() == 1 and picked_reversed.size() == 1 and picked[0] == picked_reversed[0])

	# A3 - it really is the nearest hitbox to the cursor, re-derived here from the collision
	# shapes rather than trusted.
	var mouse: Vector2 = (a as Node2D).get_global_mouse_position()
	var d_a: float = (_hitbox_centre(a) - mouse).length()
	var d_b: float = (_hitbox_centre(b) - mouse).length()
	var expected: Node = a if d_a <= d_b else b
	check("picks the hitbox nearest the cursor",
			picked.size() == 1 and picked[0] == expected,
			"a=%.0f b=%.0f" % [d_a, d_b])

	# A4 - freed entries are skipped rather than crashing a typed Node parameter. Built the way
	# the real leak happens (append while alive, freed afterwards): a typed Array[Node] REFUSES
	# an already-freed object at assignment time, so seeding one directly would test nothing.
	var dead := Node2D.new()
	add_child(dead)
	var with_dead: Array[Node] = [dead, a]
	dead.free()
	var picked_live := strike.pick_single_target(with_dead)
	check("freed candidates are skipped",
			picked_live.size() == 1 and picked_live[0] == a, str(picked_live.size()))

	# A5 - THE BUG: play() with both enemies aimed must damage exactly one of them.
	Global.dice_type = "blue"
	Global.roll_value = 5
	var hp_a: int = a.stats.health
	var hp_b: int = b.stats.health
	strike.play(both, _battle.char_stats, _player.modifier_handler)
	await get_tree().process_frame
	await get_tree().process_frame
	var hit_a: bool = a.stats.health < hp_a
	var hit_b: bool = b.stats.health < hp_b
	check("single-target play damages exactly one enemy",
			hit_a != hit_b, "a %d->%d, b %d->%d" % [hp_a, a.stats.health, hp_b, b.stats.health])
	check("the enemy damaged is the picked one",
			(picked.size() == 1) and ((picked[0] == a and hit_a) or (picked[0] == b and hit_b)))
	check("last_played_card_targets records one enemy",
			Global.last_played_card_targets.size() == 1,
			str(Global.last_played_card_targets.size()))

	# A6 - NEGATIVE CONTROL: the card itself will happily hit both when handed both, so A5 is
	# genuinely measuring the collapse in play() and not something else. This is what shipped.
	Global.roll_value = 5
	hp_a = a.stats.health
	hp_b = b.stats.health
	strike.apply_effects(both, _player.modifier_handler)
	await get_tree().process_frame
	await get_tree().process_frame
	check("negative control: raw apply_effects on both DOES hit both",
			a.stats.health < hp_a and b.stats.health < hp_b,
			"a %d->%d, b %d->%d" % [hp_a, a.stats.health, hp_b, b.stats.health])

	# A7 - AoE regression: ALL_ENEMIES cards must still fan out to every enemy from one aimed
	# body.
	var aoe := load("res://characters/warrior/cards/card_detonation.tres") as Card
	Global.dice_type = "blue"
	Global.roll_value = 4
	hp_a = a.stats.health
	hp_b = b.stats.health
	var one: Array[Node] = [a]
	aoe.play(one, _battle.char_stats, _player.modifier_handler)
	await get_tree().process_frame
	await get_tree().process_frame
	check("AoE card still hits both enemies",
			a.stats.health < hp_a and b.stats.health < hp_b,
			"a %d->%d, b %d->%d" % [hp_a, a.stats.health, hp_b, b.stats.health])


# ------------------------------------------------------------------- B. Trebuchet
func _scenario_trebuchet() -> void:
	_section("B. TREBUCHET +3 / +4")

	var base := load("res://characters/warrior/cards/card_trebuchet.tres") as Card
	var plus := load("res://characters/warrior/cards/card_trebuchet_plus.tres") as Card

	check("Trebuchet text says 3", base.description.contains("3 more damage"), base.description)
	check("Trebuchet+ text says 4", plus.description.contains("4 more damage"), plus.description)
	var status_base := load("res://statuses/status_trebuchet.tres") as Status
	var status_plus := load("res://statuses/status_trebuchet_plus.tres") as Status
	check("Trebuchet badge tooltip says 3", status_base.tooltip.contains("3 more damage"),
			status_base.tooltip)
	check("Trebuchet+ badge tooltip says 4", status_plus.tooltip.contains("4 more damage"),
			status_plus.tooltip)

	# Min 6 gate, so give it a passing roll before playing.
	var self_target: Array[Node] = [_player]
	Global.dice_type = "blue"
	Global.roll_value = 6
	Global.thrown_dice_bonus_fight = 0
	base.play(self_target, _battle.char_stats, _player.modifier_handler)
	await get_tree().process_frame
	check("Trebuchet grants +3 thrown damage", Global.thrown_dice_bonus_fight == 3,
			str(Global.thrown_dice_bonus_fight))

	Global.roll_value = 6
	Global.thrown_dice_bonus_fight = 0
	plus.play(self_target, _battle.char_stats, _player.modifier_handler)
	await get_tree().process_frame
	check("Trebuchet+ grants +4 thrown damage", Global.thrown_dice_bonus_fight == 4,
			str(Global.thrown_dice_bonus_fight))

	Global.thrown_dice_bonus_fight = 0


# ------------------------------------------------------------------ C. Sixth Gear
func _scenario_sixth_gear() -> void:
	_section("C. SIXTH GEAR: every 8 dice, 6 Power")

	var relic := load("res://relics/sixth_gear.tres") as Relic
	check("Sixth Gear tooltip says 8th", relic.tooltip.contains("8th"), relic.tooltip)
	check("Sixth Gear tooltip says 6 Power", relic.tooltip.contains("6 Power"), relic.tooltip)

	_relic_handler.add_relic(relic)
	await get_tree().process_frame

	Global.fight_dice_rolled = 6
	Global.roll_value = 0
	_fake_roll("blue", 3)  # 7th of the fight
	check("7th die grants nothing", Global.roll_value == 0, str(Global.roll_value))
	_fake_roll("blue", 3)  # 8th of the fight
	check("8th die grants 6 Power", Global.roll_value == 6, str(Global.roll_value))
	Global.roll_value = 0
	_fake_roll("blue", 3)  # 9th
	check("9th die grants nothing", Global.roll_value == 0, str(Global.roll_value))
	# Keeps paying on the next multiple of 8.
	for i in 6:
		_fake_roll("blue", 3)  # 10th..15th
	check("dice 10-15 grant nothing", Global.roll_value == 0, str(Global.roll_value))
	_fake_roll("blue", 3)  # 16th
	check("16th die grants 6 Power again", Global.roll_value == 6, str(Global.roll_value))


# ------------------------------------------------- D. aim highlight follows the pick
# The player has to be able to SEE which of two overlapping bodies is going to get hit -
# highlighting both would promise a double hit that play() no longer delivers.
func _scenario_aim_highlight() -> void:
	_section("D. AIM HIGHLIGHT PICKS ONE BODY")

	var selector := _battle.get_node_or_null("CardTargetSelector")
	check("battle has a CardTargetSelector", selector != null)
	if selector == null:
		return

	var card_ui: CardUI = null
	for child in _battle.battle_ui.hand.get_children():
		if child is CardUI:
			card_ui = child
			break
	check("found a live CardUI in hand", card_ui != null)
	if card_ui == null:
		return

	card_ui.card = load("res://characters/warrior/cards/warrior_axe_attack1.tres") as Card
	await get_tree().process_frame

	var enemies := _enemies()
	var a: Area2D = enemies[0] as Area2D
	var b: Area2D = enemies[1] as Area2D
	card_ui.targets.clear()

	Events.card_aim_started.emit(card_ui)
	await get_tree().process_frame
	selector._on_area_2d_area_entered(a)
	selector._on_area_2d_area_entered(b)
	check("both overlapping bodies are recorded as candidates",
			card_ui.targets.size() == 2, str(card_ui.targets.size()))

	var highlighted: Node = selector._highlighted_target
	check("exactly one body is highlighted",
			highlighted != null and (highlighted == a or highlighted == b))
	var picked := card_ui.card.pick_single_target(card_ui.targets)
	check("the highlighted body is the one play() would hit",
			picked.size() == 1 and highlighted == picked[0])

	# Sliding off the highlighted body must hand the highlight to the one still under the
	# cursor, not leave the aim unlit.
	selector._on_area_2d_area_exited(highlighted as Area2D)
	check("highlight falls through to the remaining body",
			card_ui.targets.size() == 1 and selector._highlighted_target == card_ui.targets[0],
			str(card_ui.targets.size()))

	selector._on_area_2d_area_exited(card_ui.targets[0] as Area2D)
	check("nothing highlighted once nothing is aimed",
			card_ui.targets.is_empty() and selector._highlighted_target == null)

	Events.card_aim_ended.emit(card_ui)
	await get_tree().process_frame


# ------------------------------------------------------------------------ helpers
func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _fatten(enemy: Node) -> void:
	enemy.stats.max_health = 500
	enemy.stats.health = 500


func _hitbox_centre(target: Node) -> Vector2:
	var node_2d := target as Node2D
	var shape := node_2d.get_node_or_null("CollisionShape2D") as Node2D
	if shape != null:
		return shape.global_position
	return node_2d.global_position


func _fake_roll(dice_type: String, value: int) -> void:
	Global.dice_type = dice_type
	Global.last_roll = value
	Global.dice_amount_rolled_this_turn += 1
	Global.fight_dice_rolled += 1
	Events.dice_rolled.emit(dice_type, value)


func _await_until(predicate: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	push_error("timeout waiting for condition")
