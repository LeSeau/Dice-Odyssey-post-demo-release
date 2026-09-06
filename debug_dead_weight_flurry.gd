extends Node

# Does holding Dead Weight actually change what Flurry deals?
#
# Two separate claims live in the two versions of the card and they travel through two
# COMPLETELY different pipes, so a harness has to test them apart:
#   base  Dead Weight   -> Surge 1, a ROLL bonus (dice.gd folds it into Global.roll_value)
#   plus  Dead Weight+  -> Surge 1 AND +1 flat damage, a HIT bonus
#                          (ModifierHandler.get_modified_value, DMG_DEALT, player only)
#
# Flurry reads Global.roll_value through the player's ModifierHandler, so on paper the base
# card lands via the roll number and the + lands on top per hit. Sections here measure the
# real enemy HP delta through the real Card.play(), plus the roll pipe on its own.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . --headless res://debug_dead_weight_flurry.tscn

const FIGHT := "res://battles/tier_1_slanderers.tres"
const FLURRY := "res://characters/warrior/cards/card_flurry.tres"
const FLURRY_PLUS := "res://characters/warrior/cards/card_flurry_plus.tres"
const DEAD_WEIGHT := "res://characters/warrior/cards/card_dead_weight.tres"
const DEAD_WEIGHT_PLUS := "res://characters/warrior/cards/card_dead_weight_plus.tres"
const STRIKE := "res://characters/warrior/cards/warrior_axe_attack1.tres"
const BLOOD_OATH := "res://characters/warrior/cards/card_blood_oath.tres"
const SLEIGHT := "res://characters/warrior/cards/card_sleight.tres"

var _battle: Node = null
var _hand: Node = null
var _pass := 0
var _fail := 0
var hands_drawn := 0


func _ready() -> void:
	Global.reset_run_state()
	Global.tutorial_on = false
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	await _boot_battle()
	await _section_a()
	await _section_b()
	await _section_c()
	await _section_d()
	await _section_e()
	await _section_f()
	await _section_g()
	print("[dw] %d passed, %d FAILED" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("[dw]  PASS  ", label, ("  " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("[dw]  FAIL  ", label, "  ", detail)


func _boot_battle() -> void:
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)

	var relic_handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	_battle.relics = relic_handler
	_battle.battle_stats = load(FIGHT)
	_battle.act_tier = 1

	var before := hands_drawn
	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > before, 15.0)
	_hand = get_tree().get_first_node_in_group("hand")
	_check("hand found", _hand != null)


func _await_until(cond: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _clear_hand() -> void:
	for child in _hand.get_children():
		if child is CardUI:
			child.free()
	await get_tree().process_frame


func _hold(path: String) -> void:
	_hand.add_card(load(path))
	await get_tree().process_frame
	await get_tree().process_frame


func _enemy() -> Enemy:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.is_queued_for_deletion():
			return e
	return null


func _player_modifiers() -> ModifierHandler:
	var p := get_tree().get_first_node_in_group("player")
	return p.modifier_handler if p != null else null


# Plays `card_path` for real (Card.play through the player's ModifierHandler) and returns the
# total HP the enemy lost, waiting past Flurry's deferred second hit.
func _damage_from(card_path: String, roll: int) -> int:
	var enemy := _enemy()
	enemy.stats.health = 9999
	enemy.stats.block = 0
	await get_tree().process_frame

	Global.roll_value = roll
	Global.dice_type = "red"
	Global.roll_history = [roll]

	var before: int = enemy.stats.health
	var card: Card = load(card_path)
	card.play([enemy], _battle.char_stats, _player_modifiers())
	# Flurry's follow-up hits are SceneTreeTimers 0.2s apart.
	await get_tree().create_timer(0.8, false).timeout
	return before - enemy.stats.health


# --- A: the surge pipe (base Dead Weight = Surge 1) -------------------------------------
# Since 2026-09-06 held Surge lives in in_hand_surge_bonus()/total_surge(), NOT in
# in_hand_roll_bonus() - that split is what lets the badge and the motes see it.
func _section_a() -> void:
	print("[dw] --- A: in_hand_surge_bonus / total_surge")
	Global.surge_amount = 0
	await _clear_hand()
	_check("empty hand -> surge bonus 0", Global.in_hand_surge_bonus() == 0,
			"got %d" % Global.in_hand_surge_bonus())

	await _hold(DEAD_WEIGHT)
	_check("holding Dead Weight -> surge bonus 1", Global.in_hand_surge_bonus() == 1,
			"got %d" % Global.in_hand_surge_bonus())
	_check("holding Dead Weight -> total_surge 1", Global.total_surge() == 1,
			"got %d" % Global.total_surge())
	# The split: held Surge must NOT come back through the non-Surge roll adder as well, or
	# every roll would get it twice.
	_check("held Surge is out of in_hand_roll_bonus (no double add)",
			Global.in_hand_roll_bonus("red") == 0, "got %d" % Global.in_hand_roll_bonus("red"))

	await _clear_hand()
	await _hold(DEAD_WEIGHT_PLUS)
	_check("holding Dead Weight+ -> surge bonus 1", Global.in_hand_surge_bonus() == 1,
			"got %d" % Global.in_hand_surge_bonus())

	# Regression: Blood Oath is the only thing left in in_hand_roll_bonus, and it is red-only.
	await _clear_hand()
	await _hold(BLOOD_OATH)
	_check("Blood Oath still gives +2 on red", Global.in_hand_roll_bonus("red") == 2,
			"got %d" % Global.in_hand_roll_bonus("red"))
	_check("Blood Oath gives nothing on blue", Global.in_hand_roll_bonus("blue") == 0,
			"got %d" % Global.in_hand_roll_bonus("blue"))
	_check("Blood Oath is not Surge", Global.in_hand_surge_bonus() == 0,
			"got %d" % Global.in_hand_surge_bonus())

	# Cast Surge and held Surge stack.
	await _clear_hand()
	await _hold(DEAD_WEIGHT)
	Global.surge_amount = 2
	_check("cast Surge 2 + held Dead Weight = total_surge 3", Global.total_surge() == 3,
			"got %d" % Global.total_surge())
	Global.surge_amount = 0


# --- B: the damage pipe (Dead Weight+ = +1 flat) ----------------------------------------
func _section_b() -> void:
	print("[dw] --- B: in_hand_damage_bonus")
	await _clear_hand()
	_check("empty hand -> damage bonus 0", Global.in_hand_damage_bonus() == 0,
			"got %d" % Global.in_hand_damage_bonus())

	await _hold(DEAD_WEIGHT)
	_check("holding Dead Weight -> damage bonus 0 (base grants no Strength)",
			Global.in_hand_damage_bonus() == 0, "got %d" % Global.in_hand_damage_bonus())

	await _clear_hand()
	await _hold(DEAD_WEIGHT_PLUS)
	_check("holding Dead Weight+ -> damage bonus 1", Global.in_hand_damage_bonus() == 1,
			"got %d" % Global.in_hand_damage_bonus())

	var mods := _player_modifiers()
	_check("modifier handler folds it into DMG_DEALT",
			mods.get_modified_value(6, Modifier.Type.DMG_DEALT) == 7,
			"6 -> %d" % mods.get_modified_value(6, Modifier.Type.DMG_DEALT))


# --- C: real Flurry damage, measured on a real enemy -------------------------------------
func _section_c() -> void:
	print("[dw] --- C: Flurry damage on a live enemy (roll 6)")

	await _clear_hand()
	await _hold(STRIKE)  # a neutral card so the hand is never empty
	var base_dmg := await _damage_from(FLURRY, 6)
	_check("Flurry, nothing held = 12 (6 x2)", base_dmg == 12, "got %d" % base_dmg)

	await _clear_hand()
	await _hold(DEAD_WEIGHT)
	var with_dw := await _damage_from(FLURRY, 6)
	_check("Flurry, holding Dead Weight = still 12 at the SAME roll",
			with_dw == 12, "got %d" % with_dw)

	await _clear_hand()
	await _hold(DEAD_WEIGHT_PLUS)
	var with_dwp := await _damage_from(FLURRY, 6)
	_check("Flurry, holding Dead Weight+ = 14 (7 x2)", with_dwp == 14, "got %d" % with_dwp)

	print("[dw]   base=%d  DeadWeight=%d  DeadWeight+=%d" % [base_dmg, with_dw, with_dwp])

	# Flurry+ is three hits, so the + card's flat bonus should scale with the hit COUNT.
	await _clear_hand()
	await _hold(STRIKE)
	var fp_base := await _damage_from(FLURRY_PLUS, 6)
	await _clear_hand()
	await _hold(DEAD_WEIGHT_PLUS)
	var fp_dwp := await _damage_from(FLURRY_PLUS, 6)
	print("[dw]   Flurry+ base=%d  with DeadWeight+=%d" % [fp_base, fp_dwp])
	_check("Flurry+ picks the flat bonus up on every hit", fp_dwp - fp_base == 3,
			"delta=%d" % (fp_dwp - fp_base))


# --- D: a REAL roll, through dice.gd, not a hand-set roll_value --------------------------
# Section C set Global.roll_value directly, which skips the pipe base Dead Weight actually
# uses. This rolls for real and reads what the Power number ends up at.
func _section_d() -> void:
	print("[dw] --- D: real rolls through dice.gd")
	var dice: Node = get_tree().get_first_node_in_group("dice_interface")
	var die: Node = _battle.get_node_or_null("ActiveDice")
	if die == null:
		_check("ActiveDice found", false, "node missing, skipping section D")
		return

	for held in [["nothing", STRIKE], ["Dead Weight", DEAD_WEIGHT], ["Dead Weight+", DEAD_WEIGHT_PLUS]]:
		await _clear_hand()
		await _hold(held[1])
		Global.dice_type = "blue"
		Global.blue_dice_current_amount = 6
		Global.roll_value = 0
		Global.roll_history = []
		Global.surge_amount = 0
		Global.next_roll_modifier = 0

		var faces: Array = []
		for i in range(3):
			die.roll_dice()
			await _await_until(func() -> bool: return not die._roll_in_progress, 5.0)
			faces.append(Global.last_roll)
		print("[dw]   held=%-13s natural faces=%s  banked Power=%d  (sum of faces=%d)"
				% [held[0], str(faces), Global.roll_value,
					faces[0] + faces[1] + faces[2]])
		var expected_bonus: int = 0 if held[0] == "nothing" else 3
		var actual_bonus: int = Global.roll_value - (faces[0] + faces[1] + faces[2])
		_check("held=%s -> +%d over three rolls" % [held[0], expected_bonus],
				actual_bonus == expected_bonus, "got +%d" % actual_bonus)


# --- E: the BADGE - what Julien actually asked for ---------------------------------------
# Holding Dead Weight has to raise the Surge icon, show the right count, and drop it again
# when the card leaves the hand. Before 2026-09-06 the Power was granted and the status row
# stayed empty, so the card's own "gain Surge 1" was a promise nothing on screen kept.
func _section_e() -> void:
	print("[dw] --- E: Surge badge follows the hand")
	Global.surge_amount = 0
	# Sections above already raised a badge and left it hidden at 0 (Surge has
	# can_expire = false, so status_ui never frees it). Drop it so this section exercises the
	# CREATION path - "player has never cast Surge, then draws Dead Weight" - for real.
	_free_surge_badge()
	await _clear_hand()
	await _hold(STRIKE)
	await _settle()
	_check("no Surge badge with nothing held", _surge_badge_stacks() == -1,
			"stacks=%d" % _surge_badge_stacks())

	await _hold(DEAD_WEIGHT)
	await _settle()
	_check("drawing Dead Weight raises the Surge badge at 1", _surge_badge_stacks() == 1,
			"stacks=%d" % _surge_badge_stacks())
	_check("badge is visible", _surge_badge_visible() == true)

	# Cast Surge on top: the two halves have to add on the badge, not replace each other.
	Global.surge_amount = 2
	Global.refresh_surge_badge()
	await _settle()
	_check("cast Surge 2 + held = badge 3", _surge_badge_stacks() == 3,
			"stacks=%d" % _surge_badge_stacks())

	# The start-of-turn resync used to write surge_amount straight onto the badge, which
	# would erase the held half once per turn.
	var badge := _surge_status()
	badge.apply_status(Global.player)
	await _settle()
	_check("start-of-turn resync keeps the held half", _surge_badge_stacks() == 3,
			"stacks=%d" % _surge_badge_stacks())

	# Discarding it takes the held half back off.
	Global.surge_amount = 0
	await _clear_hand()
	await _hold(STRIKE)
	await _settle()
	_check("losing Dead Weight drops the badge to 0", _surge_badge_stacks() == 0,
			"stacks=%d" % _surge_badge_stacks())
	_check("badge hides at 0 (hide_when_zero)", _surge_badge_visible() == false)


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _surge_status() -> Status:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return null
	for child in p.status_handler.get_children():
		if child is StatusUI and child.status != null and child.status.id == "surge":
			return child.status
	return null


# -1 = no badge at all, which is different from a badge sitting at 0.
func _surge_badge_stacks() -> int:
	var st := _surge_status()
	return -1 if st == null else st.stacks


func _surge_badge_visible() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	for child in p.status_handler.get_children():
		if child is StatusUI and child.status != null and child.status.id == "surge":
			return child.visible
	return false


func _free_surge_badge() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	for child in p.status_handler.get_children():
		if child is StatusUI and child.status != null and child.status.id == "surge":
			child.free()


# --- F: the die-side tell (surge motes) --------------------------------------------------
# dice.gd's mote timer now reads total_surge(). debug_surge_motes.gd covers this properly but
# it renders stills, so it needs a window; this asserts the one line that changed without
# opening one. Also the regression guard: with nothing held, total_surge() == surge_amount,
# so every existing mote scenario has to behave byte-identically.
func _section_f() -> void:
	print("[dw] --- F: surge mote density reads total_surge")
	var die: Node = _battle.get_node_or_null("ActiveDice")
	if die == null:
		_check("ActiveDice found", false, "node missing")
		return

	Global.surge_amount = 0
	await _clear_hand()
	await _hold(STRIKE)
	var idle: float = die._surge_mote_interval(Global.total_surge())

	# Cast Surge 2, nothing held.
	Global.surge_amount = 2
	var cast_2: float = die._surge_mote_interval(Global.total_surge())
	_check("cast Surge 2 thickens the motes", cast_2 < idle,
			"idle=%.3f cast2=%.3f" % [idle, cast_2])

	# Held Dead Weight instead of cast Surge: same count, so the same density.
	Global.surge_amount = 0
	await _clear_hand()
	await _hold(DEAD_WEIGHT)
	await _hold(DEAD_WEIGHT_PLUS)  # 1 + 1 = the same 2
	var held_2: float = die._surge_mote_interval(Global.total_surge())
	_check("held Surge 2 gives the SAME density as cast Surge 2",
			is_equal_approx(held_2, cast_2), "held=%.3f cast=%.3f" % [held_2, cast_2])

	# Regression: nothing held means the old surge_amount path is untouched.
	await _clear_hand()
	await _hold(STRIKE)
	Global.surge_amount = 3
	_check("nothing held -> total_surge == surge_amount (mote scenarios unchanged)",
			Global.total_surge() == Global.surge_amount,
			"total=%d amount=%d" % [Global.total_surge(), Global.surge_amount])
	Global.surge_amount = 0


# --- G: the Strength badge, and the double-count it must not cause -----------------------
# Dead Weight+ promised "1 Strength" while granting no stack and no icon. The count is now
# LENT to the badge (Status.display_bonus) instead of being added to stacks, because
# MuscleStatus writes stacks straight into the "muscle" ModifierValue - a real stack would
# hand the player the damage twice. G3 is the check that pins that.
func _section_g() -> void:
	print("[dw] --- G: Strength badge follows the hand")
	_free_strength_badge()
	Global.surge_amount = 0
	await _clear_hand()
	await _hold(STRIKE)
	await _settle()
	_check("no Strength badge with nothing held", _strength_shown() == -1,
			"shown=%d" % _strength_shown())

	await _hold(DEAD_WEIGHT_PLUS)
	await _settle()
	_check("drawing Dead Weight+ raises the Strength badge at 1", _strength_shown() == 1,
			"shown=%d" % _strength_shown())
	_check("badge is visible", _strength_visible() == true)

	# G3: the lent number must NOT reach the modifier, or 6 damage would become 8.
	var st := _strength_status()
	_check("held Strength is lent, not owned (stacks stay 0)", st.stacks == 0,
			"stacks=%d" % st.stacks)
	var mods := _player_modifiers()
	_check("no double count: 6 -> 7, not 8",
			mods.get_modified_value(6, Modifier.Type.DMG_DEALT) == 7,
			"6 -> %d" % mods.get_modified_value(6, Modifier.Type.DMG_DEALT))

	# Real cast Strength on top: the badge adds, and only the CAST half reaches the modifier
	# twice-over-free. 2 cast + 1 held = badge 3, damage 6 -> 9.
	st.stacks = 2
	Global.refresh_strength_badge()
	await _settle()
	_check("cast Strength 2 + held = badge 3", _strength_shown() == 3,
			"shown=%d" % _strength_shown())
	_check("cast 2 + held 1: 6 -> 9",
			mods.get_modified_value(6, Modifier.Type.DMG_DEALT) == 9,
			"6 -> %d" % mods.get_modified_value(6, Modifier.Type.DMG_DEALT))

	# Losing the card takes the lent half back off, badge and damage together.
	st.stacks = 0
	await _clear_hand()
	await _hold(STRIKE)
	await _settle()
	_check("losing Dead Weight+ drops the badge to 0", _strength_shown() == 0,
			"shown=%d" % _strength_shown())
	_check("badge created by the held bonus hides at 0", _strength_visible() == false)
	_check("and the damage goes back to base: 6 -> 6",
			mods.get_modified_value(6, Modifier.Type.DMG_DEALT) == 6,
			"6 -> %d" % mods.get_modified_value(6, Modifier.Type.DMG_DEALT))

	# End to end on Flurry: the badge says 1 and Flurry really does deal 7 twice.
	await _clear_hand()
	await _hold(DEAD_WEIGHT_PLUS)
	await _settle()
	var dmg := await _damage_from(FLURRY, 6)
	_check("badge 1 and Flurry deals 14 - the icon matches the damage",
			_strength_shown() == 1 and dmg == 14, "shown=%d dmg=%d" % [_strength_shown(), dmg])

	# Regression: display_bonus defaults to 0, so no other status changed shape.
	var weak: Status = load("res://statuses/weak.tres")
	_check("an untouched status still displays its raw stacks",
			weak.display_stacks() == weak.stacks,
			"display=%d stacks=%d" % [weak.display_stacks(), weak.stacks])


func _strength_status() -> Status:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return null
	for child in p.status_handler.get_children():
		if child is StatusUI and child.status != null and child.status.id == "strength":
			return child.status
	return null


func _strength_shown() -> int:
	var st := _strength_status()
	return -1 if st == null else st.display_stacks()


func _strength_visible() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	for child in p.status_handler.get_children():
		if child is StatusUI and child.status != null and child.status.id == "strength":
			return child.visible
	return false


func _free_strength_badge() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	for child in p.status_handler.get_children():
		if child is StatusUI and child.status != null and child.status.id == "strength":
			child.free()
