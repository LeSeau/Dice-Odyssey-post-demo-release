extends Node

# Verification harness for the 2026-08-28 attack-animation pass (batches 1-4):
#
#   A. BODY LUNGE      - the hero's root moves toward the enemies on an attack and returns to
#                        exactly where it started; a non-attack card moves nothing; being hit
#                        mid-lunge still ends at rest (the shared-tween arbitration).
#   B. PUNCH LADDER    - the held die's excursion grows with the size of the hit, and hits that
#                        are NOT the played card (enemy attacks, thrown-die landings) move it
#                        not at all.
#   C. DIE STRIKE      - fires on a big single-target hit and on a lethal small one; never on
#                        AoE, never on a small non-lethal hit, never twice in one play, never
#                        on a card that reads its target after damaging it; the damage that
#                        lands is bit-identical to the undeferred path; it never reports itself
#                        as a rolled/thrown die; the palm always refills.
#   D. KILL LOOP       - a lethal strike leaves the enemy alive until the die actually arrives,
#                        then kills it (so the dice-shard burst reads as caused by the die).
#
# Boots a REAL battle.tscn (recipe from debug_single_target_hitbox.gd) so everything runs
# through the real Card.play() -> DamageEffect -> Enemy.take_damage path.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --headless --path . res://debug_attack_anim.tscn

const FIGHT := "res://battles/tier_1_crab_satyr.tres"

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _relic_handler: RelicHandler
var _player: Player
var _thrown_landed := 0


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
	Global.tutorial_on = true  # no achievement toasts from synthetic plays
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	# The strike must never masquerade as a rolled die - that would fire the throw relics
	# (Hunting Bow, Snake Eyes Charm, Metronome, Greedy) and the roll counters.
	Events.dice_thrown_landed.connect(func(_t, _v) -> void: _thrown_landed += 1)

	if OS.get_environment("ATTACK_ANIM_MODE").to_lower() == "render":
		await _run_render()
		return

	await _boot_battle()
	await _scenario_lunge()
	await _scenario_punch_ladder()
	await _scenario_strike_gating()
	await _scenario_strike_damage_parity()
	await _scenario_kill_loop()

	print("\n==== ATTACK ANIM: %d checks, %d fail(s) ====" % [checks, fails])
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
	_battle.battle_stats = load(FIGHT)   # the .tres, never the .tscn
	_battle.act_tier = 1
	_relic_handler.add_relic(warrior.starting_relic)

	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 15.0)
	_player = get_tree().get_first_node_in_group("player") as Player
	check("battle booted", _player != null)
	check("player exposes the new API",
			_player != null and _player.has_method("strike_with_die")
			and _player.has_method("lunge_body")
			and _player.has_method("punch_held_die_for_impact"))
	# Type degradation is invisible to gdtoolkit and only shows up when the engine actually
	# loads the script, so prove each edited file parses in a booted engine.
	for path in ["res://effects/damage_effect.gd", "res://custom_resources/card.gd",
			"res://scenes/player/player.gd", "res://characters/warrior/cards/executioner.gd",
			"res://characters/warrior/cards/clank.gd",
			"res://characters/warrior/cards/clank_plus.gd"]:
		check("loads in engine: " + path.get_file(), load(path) != null)


# --- render mode ------------------------------------------------------------------------------
# Boots the REAL battle (not a composed still life) because the strike needs the ui_layer its
# clone flies on, and the kill beat needs the real death sequence with its dice-shard burst.
#
# Run:
#   ATTACK_ANIM_MODE=render Godot_v4.3-stable_win64_console.exe --path . \
#       res://debug_attack_anim.tscn --write-movie attack_anim_frames/f.png --fixed-fps 30 \
#       --rendering-driver opengl3 --resolution 1280x720 --position 2000,2000
func _run_render() -> void:
	if not OS.has_feature("movie"):
		push_error("[attack_anim] run with --write-movie <dir>/f.png --fixed-fps 30")
		get_tree().quit(1)
		return

	# Tutorial OFF for the render: the check mode leaves it on only to keep achievement toasts
	# out of the way, but in a rendered frame the tutorial's dialog box covers the fight.
	Global.tutorial_on = false
	await _boot_battle()
	Global.dice_type = "blue"
	Events.active_dice_changed.emit("blue")
	await _settle(1.0)

	var beats := [
		{"label": "SMALL (punch only, 4 dmg)", "dmg": 4, "single": true, "hp": 500},
		{"label": "BIG (strike, 22 dmg)", "dmg": 22, "single": true, "hp": 500},
		{"label": "LETHAL (strike + shatter)", "dmg": 40, "single": true, "hp": 14},
	]
	for beat in beats:
		var living := _enemies()
		if living.is_empty():
			break
		var target: Node = living[0]
		target.stats.max_health = 500
		target.stats.health = int(beat["hp"])
		target.stats.block = 0
		await _settle(0.8)
		print("[attack_anim] %s at frame %d" % [beat["label"], Engine.get_process_frames()])
		Global.last_attack_card_played_frame = Engine.get_process_frames()
		Global.last_attack_card_single_target = bool(beat["single"])
		Global.playing_card_observes_post_damage = false
		Global.die_strike_frame = -1
		Global.die_reaction_frame = -1
		var e := DamageEffect.new()
		e.amount = int(beat["dmg"])
		e.execute([target] as Array[Node])
		await _settle(2.4)

	print("[attack_anim] render done at frame %d" % Engine.get_process_frames())
	get_tree().quit()


# --- A. body lunge --------------------------------------------------------------------------
func _scenario_lunge() -> void:
	_section("A. body lunge")
	var rest: Vector2 = _player.position

	# An ATTACK card play must shove the body toward the enemies.
	Global.dice_type = "blue"
	Global.roll_value = 5
	var peak := await _peak_offset_during(func() -> void:
		_play_card("res://characters/warrior/cards/warrior_axe_attack1.tres"))
	check("attack lunges the body", peak >= 12.0, "peak=%.1fpx" % peak)
	await _settle(0.6)
	check("body returns to rest after lunge",
			_player.position.distance_to(rest) <= 0.5,
			"delta=%.3f" % _player.position.distance_to(rest))

	# NEGATIVE CONTROL: a non-attack card must not.
	Global.roll_value = 5
	var peak_skill := await _peak_offset_during(func() -> void:
		_play_card("res://characters/warrior/cards/warrior_block1.tres"))
	check("NEGATIVE: block card does not lunge", peak_skill < 1.0, "peak=%.2fpx" % peak_skill)
	await _settle(0.6)

	# Arbitration: hit DURING a lunge. Both write self.position; the shared tween slot plus a
	# single canonical rest is what stops the hero drifting one hit at a time.
	Global.roll_value = 5
	_play_card("res://characters/warrior/cards/warrior_axe_attack1.tres")
	await _settle(0.04)
	_player.take_damage(3, Modifier.Type.DMG_TAKEN)
	await _settle(1.2)
	check("lunge interrupted by a hit still ends at rest",
			_player.position.distance_to(rest) <= 0.5,
			"delta=%.3f" % _player.position.distance_to(rest))


# --- B. punch ladder ------------------------------------------------------------------------
func _scenario_punch_ladder() -> void:
	_section("B. punch ladder")
	var pivot: Node2D = _player.get_node_or_null("SpriteRoot/HeldDieBob/HeldDiePivot")
	check("held-die rig has a bob node above the pivot", pivot != null)
	if pivot == null:
		return

	var small := await _peak_pivot_for_damage(3)
	var mid := await _peak_pivot_for_damage(12)
	var big := await _peak_pivot_for_damage(40)
	check("punch grows with the hit", small < mid and mid < big,
			"3dmg=%.1f 12dmg=%.1f 40dmg=%.1f" % [small, mid, big])

	# NEGATIVE CONTROL 1: an enemy hitting the PLAYER must never produce an ATTACK punch. It
	# does now produce a small recoil flinch (batch 5), so the test is that the motion stays
	# in flinch territory and never reaches the smallest thrust - not that it is zero.
	var flinch_px: float = Player.DIE_PUNCH_OFFSET.length() * absf(Player.DIE_FLINCH_STRENGTH)
	var peak_enemy := await _peak_pivot_during(func() -> void:
		var e := DamageEffect.new()
		e.amount = 30
		e.execute([_player] as Array[Node]))
	check("NEGATIVE: enemy attack never punches the die", peak_enemy < small * 0.75,
			"peak=%.1f vs smallest thrust %.1f" % [peak_enemy, small])
	check("die flinches when the player is hit",
			peak_enemy >= 4.0 and absf(peak_enemy - flinch_px) < 2.0,
			"peak=%.1fpx expected~%.1f" % [peak_enemy, flinch_px])
	await _settle(0.8)

	# NEGATIVE CONTROL 2: damage NOT belonging to the card played this frame (a thrown die
	# landing, a status payout, thorns) must not move it either.
	Global.last_attack_card_played_frame = -1
	# Typed explicitly: _enemies() returns an untyped Array, so indexing it yields Variant and
	# `:=` cannot infer - the parse error that takes down a whole file while gdtoolkit calls
	# it clean, and turns a harness into an infinite hang.
	var target: Node = _enemies()[0]
	_fatten(target)
	var peak_offframe := await _peak_pivot_during(func() -> void:
		var e := DamageEffect.new()
		e.amount = 30
		e.execute([target] as Array[Node]))
	check("NEGATIVE: off-frame damage does not punch the die", peak_offframe < 0.5,
			"peak=%.3f" % peak_offframe)
	await _settle(0.8)


# --- C. strike gating -----------------------------------------------------------------------
func _scenario_strike_gating() -> void:
	_section("C. strike gating")
	# Typed explicitly: _enemies() returns an untyped Array, so indexing it yields Variant and
	# `:=` cannot infer - the parse error that takes down a whole file while gdtoolkit calls
	# it clean, and turns a harness into an infinite hang.
	check("STRONG single-target hit fires the strike",
			await _strike_fired(20, true, false))
	check("lethal small hit fires the strike",
			await _strike_fired(6, true, false, true))
	check("NEGATIVE: small non-lethal hit does not",
			not await _strike_fired(5, true, false))
	check("NEGATIVE: AoE hit does not",
			not await _strike_fired(20, false, false))
	check("NEGATIVE: post-damage-observing card does not",
			not await _strike_fired(20, true, true))

	# Once per play: two DamageEffects in the SAME frame (an AoE-shaped multi-hit) may only
	# launch one die.
	var living := _enemies()
	if living.is_empty():
		check("once-per-play guard (no enemy left to test)", false)
		return
	var target: Node = living[0]
	_fatten(target)
	Global.last_attack_card_played_frame = Engine.get_process_frames()
	Global.last_attack_card_single_target = true
	Global.playing_card_observes_post_damage = false
	Global.die_strike_frame = -1
	# Measured by whether the DAMAGE was deferred, not by the frame guard's own value: the
	# guard reads "true" for the rest of the frame once it has fired, so testing it would
	# count the second hit as a launch even when it correctly fell through.
	var hp0: int = target.stats.health
	var e_first := DamageEffect.new()
	e_first.amount = 20
	e_first.execute([target] as Array[Node])
	var hp_after_first: int = target.stats.health
	var e_second := DamageEffect.new()
	e_second.amount = 20
	e_second.execute([target] as Array[Node])
	var hp_after_second: int = target.stats.health
	check("first hit of the play is taken by the die", hp_after_first == hp0,
			"hp %d -> %d" % [hp0, hp_after_first])
	check("second hit in the same play resolves immediately (only one strike)",
			hp_after_second < hp_after_first,
			"hp %d -> %d" % [hp_after_first, hp_after_second])
	await _settle(1.4)

	check("no strike ever reported itself as a thrown die", _thrown_landed == 0,
			"count=%d" % _thrown_landed)
	var pivot: Node2D = _player.get_node_or_null("SpriteRoot/HeldDieBob/HeldDiePivot")
	check("palm refilled after every strike", pivot != null and pivot.visible)


# --- C2. damage parity ----------------------------------------------------------------------
# The deferral must move WHEN the hit lands, never WHAT it does.
func _scenario_strike_damage_parity() -> void:
	_section("C2. deferral does not change the maths")
	# Typed explicitly: _enemies() returns an untyped Array, so indexing it yields Variant and
	# `:=` cannot infer - the parse error that takes down a whole file while gdtoolkit calls
	# it clean, and turns a harness into an infinite hang.
	var target: Node = _enemies()[0]

	# With the strike (deferred).
	_fatten(target)
	var hp0: int = target.stats.health
	Global.last_attack_card_played_frame = Engine.get_process_frames()
	Global.last_attack_card_single_target = true
	Global.playing_card_observes_post_damage = false
	Global.die_strike_frame = -1
	var e1 := DamageEffect.new()
	e1.amount = 20
	e1.execute([target] as Array[Node])
	var hp_mid: int = target.stats.health
	check("damage is genuinely deferred (HP unchanged at launch)", hp_mid == hp0,
			"hp %d -> %d" % [hp0, hp_mid])
	await _settle(1.4)
	var dealt_deferred: int = hp0 - target.stats.health

	# Without the strike (immediate) - same hit, strike suppressed by the AoE gate.
	_fatten(target)
	var hp1: int = target.stats.health
	Global.last_attack_card_played_frame = Engine.get_process_frames()
	Global.last_attack_card_single_target = false
	Global.die_strike_frame = -1
	var e2 := DamageEffect.new()
	e2.amount = 20
	e2.execute([target] as Array[Node])
	var dealt_immediate: int = hp1 - target.stats.health
	check("deferred damage == immediate damage",
			dealt_deferred == dealt_immediate and dealt_deferred > 0,
			"deferred=%d immediate=%d" % [dealt_deferred, dealt_immediate])
	await _settle(0.8)


# --- D. kill loop ---------------------------------------------------------------------------
func _scenario_kill_loop() -> void:
	_section("D. kill loop")
	# Typed explicitly: _enemies() returns an untyped Array, so indexing it yields Variant and
	# `:=` cannot infer - the parse error that takes down a whole file while gdtoolkit calls
	# it clean, and turns a harness into an infinite hang.
	var target: Node = _enemies()[0]
	target.stats.max_health = 12
	target.stats.health = 12
	target.stats.block = 0

	Global.last_attack_card_played_frame = Engine.get_process_frames()
	Global.last_attack_card_single_target = true
	Global.playing_card_observes_post_damage = false
	Global.die_strike_frame = -1
	var e := DamageEffect.new()
	e.amount = 40
	e.execute([target] as Array[Node])

	check("lethal target still alive while the die is in the air",
			is_instance_valid(target) and target.is_in_group("enemies")
			and target.stats.health > 0, "hp=%d" % target.stats.health)
	await _settle(1.6)
	check("target is dead once the die has landed",
			not is_instance_valid(target) or not target.is_in_group("enemies")
			or target.stats.health <= 0)


# --- helpers ---------------------------------------------------------------------------------
# Fetches its own living target each time: the lethal case genuinely kills one, and reusing a
# freed node across cases would abort the coroutine mid-scenario (and silently skip the rest
# of the checks).
func _strike_fired(dmg: int, single: bool, observes: bool, make_lethal := false) -> bool:
	var living := _enemies()
	if living.is_empty():
		return false
	var target: Node = living[0]
	if make_lethal:
		target.stats.max_health = 500
		target.stats.health = 3
		target.stats.block = 0
	else:
		_fatten(target)
	Global.last_attack_card_played_frame = Engine.get_process_frames()
	Global.last_attack_card_single_target = single
	Global.playing_card_observes_post_damage = observes
	Global.die_strike_frame = -1
	var e := DamageEffect.new()
	e.amount = dmg
	e.execute([target] as Array[Node])
	var fired: bool = Global.die_strike_frame == Engine.get_process_frames()
	await _settle(1.4)
	return fired


func _peak_pivot_for_damage(dmg: int) -> float:
	# Typed explicitly: _enemies() returns an untyped Array, so indexing it yields Variant and
	# `:=` cannot infer - the parse error that takes down a whole file while gdtoolkit calls
	# it clean, and turns a harness into an infinite hang.
	var target: Node = _enemies()[0]
	_fatten(target)
	# Force the punch path, never the strike, so this measures thrust alone.
	Global.last_attack_card_single_target = false
	var peak := await _peak_pivot_during(func() -> void:
		Global.last_attack_card_played_frame = Engine.get_process_frames()
		Global.die_reaction_frame = -1
		var e := DamageEffect.new()
		e.amount = dmg
		e.execute([target] as Array[Node]))
	await _settle(0.9)
	return peak


# Sampling is by GAME TIME, never by frame count: headless runs the main loop as fast as it
# can, so a fixed number of frames can cover a couple of milliseconds - long enough to catch
# only the anticipation pull-back and report it as the punch's peak.
const SAMPLE_WINDOW := 0.8


func _peak_pivot_during(action: Callable) -> float:
	var pivot: Node2D = _player.get_node_or_null("SpriteRoot/HeldDieBob/HeldDiePivot")
	if pivot == null:
		return -1.0
	var rest: Vector2 = pivot.position
	action.call()
	var peak := 0.0
	var t := 0.0
	while t < SAMPLE_WINDOW:
		await get_tree().process_frame
		t += get_process_delta_time()
		peak = maxf(peak, pivot.position.distance_to(rest))
	return peak


func _peak_offset_during(action: Callable) -> float:
	var rest: Vector2 = _player.position
	action.call()
	var peak := 0.0
	var t := 0.0
	while t < SAMPLE_WINDOW:
		await get_tree().process_frame
		t += get_process_delta_time()
		peak = maxf(peak, _player.position.distance_to(rest))
	return peak


func _play_card(path: String) -> void:
	var card: Card = load(path)
	if card == null:
		return
	var targets: Array[Node] = _enemies()
	card.play(targets, _battle.char_stats, _player.modifier_handler)


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _fatten(enemy: Node) -> void:
	enemy.stats.max_health = 500
	enemy.stats.health = 500
	enemy.stats.block = 0


func _settle(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _await_until(predicate: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	push_error("timeout waiting for condition")
