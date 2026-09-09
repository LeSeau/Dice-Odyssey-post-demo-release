extends Node

# The 2026-09-09 draw batch: one card (Insight / Insight+) and three relics (Streak Charm,
# Tally Stick, Deep Pockets), all answering Julien's 09-08 note that a dice engine outruns a
# five-card hand.
#
# What each section is actually guarding:
#   A  data      the pools really contain them, ids are unique, the "+" inherits its base's
#                rarity_tier (a pool-wide invariant since 2026-07-20)
#   B  Insight   integer division and the Max gate, including the two failure shapes: a bank
#                too small to buy a card, and a bank ABOVE the cap (must do nothing at all,
#                and must not eat the Power)
#   C  Insight+  the "+" reuses the same script, so the only thing that can differ is the gate
#   D  Streak    fires on chain 3 and 6, and does NOT double-fire on a Ricochet reroll. That
#                reroll case is the whole reason Global.streak_chain_seen exists, so it also
#                runs a NEGATIVE CONTROL: with the guard bypassed the same input must pay
#                twice, otherwise the check proves nothing.
#   E  Tally     every 10th die of the FIGHT, counted across turns
#   F  Deep      empty hand + a die left = draw 2, once per turn, and never on an empty pool
#
# Relics are added one at a time and torn down after their section: Streak Charm and Tally
# Stick both listen to dice_rolled and both pay through Events.draw_card, so leaving one
# connected would silently inflate the next section's count.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . --headless res://debug_draw_batch.tscn

const FIGHT := "res://battles/tier_1_slanderers.tres"
const INSIGHT := "res://characters/warrior/cards/card_insight.tres"
const INSIGHT_PLUS := "res://characters/warrior/cards/card_insight_plus.tres"
const STREAK := "res://relics/streak_charm.tres"
const TALLY := "res://relics/tally_stick.tres"
const POCKETS := "res://relics/deep_pockets.tres"
const CARD_POOL := "res://characters/warrior/warrior_draftable_cards.tres"
const RELIC_POOL := "res://treasure_relic_pool.tres"
const SHOP_POOL := "res://shop_relic_pool.tres"

var _battle: Node = null
var _hand: Node = null
var _relic_handler: RelicHandler = null
var _pass := 0
var _fail := 0
var _draws := 0
var hands_drawn := 0


func _ready() -> void:
	Global.reset_run_state()
	Global.tutorial_on = false
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	Events.draw_card.connect(func(n: int) -> void: _draws += n)
	_section_a()
	await _boot_battle()
	await _section_b()
	await _section_c()
	await _section_d()
	await _section_e()
	await _section_f()
	await _section_g()
	print("[draw] %d passed, %d FAILED" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("[draw]  PASS  ", label, ("  " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("[draw]  FAIL  ", label, "  ", detail)


# --- A: data ------------------------------------------------------------------------------

func _section_a() -> void:
	print("[draw] --- A data ---")
	var insight: Card = load(INSIGHT)
	var plus: Card = load(INSIGHT_PLUS)
	_check("Insight loads", insight != null)
	_check("Insight is Common", insight.rarity_tier == 0, str(insight.rarity_tier))
	_check("Insight gate is Max 8",
			insight.requirement == Card.Requirement.MAX and insight.requirement_number == 8,
			"%d/%d" % [insight.requirement, insight.requirement_number])
	_check("Insight+ gate is Max 12",
			plus.requirement == Card.Requirement.MAX and plus.requirement_number == 12,
			"%d/%d" % [plus.requirement, plus.requirement_number])
	_check("Insight -> Insight+ is wired", insight.upgraded_version == plus)
	_check("Insight+ is flagged upgraded", plus.upgraded)
	# Pool-wide invariant: a "+" inherits its base's rarity_tier (the gem is cosmetic on a "+"
	# but it shows in the deck view and in the campfire before/after).
	_check("Insight+ inherits the base rarity", plus.rarity_tier == insight.rarity_tier)
	_check("Insight+ has no upgrade of its own", plus.upgraded_version == null)

	var pool: CardPile = load(CARD_POOL)
	var ids := {}
	var found := false
	for c in pool.cards:
		if c == null:
			continue
		_check("no duplicate card id: " + str(c.id), not ids.has(c.id), str(c.id))
		ids[c.id] = true
		if c.id == "card_insight":
			found = true
	_check("Insight is in the draftable pool", found, "%d cards" % pool.cards.size())
	_check("Insight+ is NOT draftable", not ids.has("card_insight_plus"))

	for path in [RELIC_POOL, SHOP_POOL]:
		var rp = load(path)
		var have := {}
		for r in rp.pool:
			if r != null:
				_check("no duplicate relic id: " + str(r.id) + " in " + path.get_file(),
						not have.has(r.id), str(r.id))
				have[r.id] = true
		for want in ["streak_charm", "tally_stick", "deep_pockets"]:
			_check("%s in %s" % [want, path.get_file()], have.has(want), "%d relics" % rp.pool.size())


# --- boot ---------------------------------------------------------------------------------

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
	_battle.relics = _relic_handler
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


func _hand_size() -> int:
	var n := 0
	for child in _hand.get_children():
		if child is CardUI:
			n += 1
	return n


# Mirrors dice.gd's order: roll_history.append() runs BEFORE dice_rolled is emitted, and both
# roll paths bump fight_dice_rolled first.
func _sim_roll(face: int) -> void:
	Global.fight_dice_rolled += 1
	Global.last_roll = face
	Global.roll_history.append(face)
	Events.dice_rolled.emit(Global.dice_type, Global.roll_value)


# A Ricochet reroll: the die is re-rolled, so history is REWOUND (size stays put) but
# dice_rolled fires again and fight_dice_rolled counts it as a second roll.
func _sim_reroll(face: int) -> void:
	Global.fight_dice_rolled += 1
	Global.last_roll = face
	Global.roll_history[Global.roll_history.size() - 1] = face
	Events.dice_rolled.emit(Global.dice_type, Global.roll_value)


func _break_chain() -> void:
	Global.roll_history.clear()
	Global.streak_chain_seen = 0


func _add_relic(path: String) -> RelicUI:
	_relic_handler.add_relic(load(path))
	await get_tree().process_frame
	for ui in _relic_handler.relics.get_children():
		if ui is RelicUI and ui.relic != null and ui.relic.resource_path == path:
			return ui
	return null


func _drop_relic(ui: RelicUI) -> void:
	if ui == null:
		return
	ui.relic.deactivate_relic(ui)
	ui.queue_free()
	await get_tree().process_frame


func _player() -> Array[Node]:
	var out: Array[Node] = []
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		out.append(p)
	return out


# --- B / C: Insight -----------------------------------------------------------------------

func _play_insight(path: String, power: int) -> int:
	Global.roll_value = power
	Global.roll_history = [power]
	var card: Card = load(path)
	var before := _draws
	card.apply_effects(_player(), ModifierHandler.new())
	await get_tree().process_frame
	return _draws - before


func _section_b() -> void:
	print("[draw] --- B Insight ---")
	for pair in [[8, 4], [6, 3], [2, 1], [1, 0]]:
		var power: int = pair[0]
		var want: int = pair[1]
		var got: int = await _play_insight(INSIGHT, power)
		_check("Insight at %d Power draws %d" % [power, want], got == want, "got %d" % got)
		_check("Insight at %d Power spent the bank" % power, Global.roll_value == 0,
				str(Global.roll_value))

	# Above the cap the card is dead: no draw AND no reset. A card that ate your bank for
	# nothing would be the worst possible failure mode on a Max gate.
	Global.roll_value = 9
	Global.roll_history = [9]
	var before := _draws
	(load(INSIGHT) as Card).apply_effects(_player(), ModifierHandler.new())
	await get_tree().process_frame
	_check("Insight above Max 8 draws nothing", _draws == before, "drew %d" % (_draws - before))
	_check("Insight above Max 8 keeps the Power", Global.roll_value == 9, str(Global.roll_value))


func _section_c() -> void:
	print("[draw] --- C Insight+ ---")
	var got: int = await _play_insight(INSIGHT_PLUS, 12)
	_check("Insight+ at 12 Power draws 6", got == 6, "got %d" % got)
	Global.roll_value = 13
	Global.roll_history = [13]
	var before := _draws
	(load(INSIGHT_PLUS) as Card).apply_effects(_player(), ModifierHandler.new())
	await get_tree().process_frame
	_check("Insight+ above Max 12 draws nothing", _draws == before)
	# Same script, different gate: proves the "+" is not a stale copy of the base numbers.
	Global.roll_value = 12
	Global.roll_history = [12]
	before = _draws
	(load(INSIGHT) as Card).apply_effects(_player(), ModifierHandler.new())
	await get_tree().process_frame
	_check("base Insight at 12 Power is still dead", _draws == before,
			"drew %d" % (_draws - before))


# --- D: Streak Charm ----------------------------------------------------------------------

func _section_d() -> void:
	print("[draw] --- D Streak Charm ---")
	var ui := await _add_relic(STREAK)
	_check("Streak Charm equipped", ui != null)
	_break_chain()

	var before := _draws
	_sim_roll(4)
	_sim_roll(4)
	_check("no draw at chain 2", _draws == before, "drew %d" % (_draws - before))
	_sim_roll(4)
	_check("draws 1 at chain 3", _draws - before == 1, "drew %d" % (_draws - before))

	# The reroll case. History is rewound, so the chain is still 3 - paying again here would
	# hand out a card for a die that was already paid for.
	before = _draws
	_sim_reroll(6)
	_check("a Ricochet reroll at chain 3 does NOT pay twice", _draws == before,
			"drew %d" % (_draws - before))

	before = _draws
	_sim_roll(4)
	_sim_roll(4)
	_sim_roll(4)
	_check("draws again at chain 6", _draws - before == 1, "drew %d" % (_draws - before))

	# Breaking the chain (any card play or dice-type switch does this) restarts the count.
	_break_chain()
	before = _draws
	_sim_roll(4)
	_sim_roll(4)
	_check("a fresh chain pays nothing at 2", _draws == before)
	_sim_roll(4)
	_check("a fresh chain pays at 3", _draws - before == 1, "drew %d" % (_draws - before))

	# NEGATIVE CONTROL: bypass the guard by pretending the chain was never seen, then replay
	# the exact reroll input. It MUST pay twice - if it does not, the check above was inert.
	_break_chain()
	_sim_roll(4)
	_sim_roll(4)
	_sim_roll(4)
	before = _draws
	Global.streak_chain_seen = 0
	_sim_reroll(6)
	_check("negative control: without the guard the reroll DOES pay twice",
			_draws - before == 1, "drew %d" % (_draws - before))

	await _drop_relic(ui)
	_break_chain()


# --- E: Tally Stick -----------------------------------------------------------------------

func _section_e() -> void:
	print("[draw] --- E Tally Stick ---")
	var ui := await _add_relic(TALLY)
	_check("Tally Stick equipped", ui != null)
	Global.fight_dice_rolled = 0
	_break_chain()

	var before := _draws
	for i in 9:
		_sim_roll(3)
	_check("nothing at 9 dice", _draws == before, "drew %d" % (_draws - before))
	_sim_roll(3)
	_check("draws 2 at the 10th die", _draws - before == 2, "drew %d" % (_draws - before))

	# Counted across the fight, not the turn: the chain breaks here and it keeps counting.
	before = _draws
	_break_chain()
	for i in 10:
		_sim_roll(3)
	_check("draws 2 again at the 20th die, across a broken chain",
			_draws - before == 2, "drew %d" % (_draws - before))

	await _drop_relic(ui)


# --- F: Deep Pockets ----------------------------------------------------------------------

func _section_f() -> void:
	print("[draw] --- F Deep Pockets ---")
	var ui := await _add_relic(POCKETS)
	_check("Deep Pockets equipped", ui != null)
	Global.deep_pockets_fired_this_turn = false
	Global.blue_dice_current_amount = 2
	await _clear_hand()
	_check("hand really is empty", _hand_size() == 0, str(_hand_size()))

	var before := _draws
	Events.card_played.emit(load(INSIGHT))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("empty hand + a die left draws 2", _draws - before == 2, "drew %d" % (_draws - before))

	# Once per turn. The draw above put real cards back in the hand, so clear it first -
	# otherwise this would pass for the wrong reason (a non-empty hand, not the flag).
	await _clear_hand()
	before = _draws
	Events.card_played.emit(load(INSIGHT))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("does not fire twice in one turn", _draws == before, "drew %d" % (_draws - before))

	# A new turn re-arms it (dice_interface clears the flag at the start of every turn).
	Global.deep_pockets_fired_this_turn = false
	await _clear_hand()
	before = _draws
	Events.card_played.emit(load(INSIGHT))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("re-arms next turn", _draws - before == 2, "drew %d" % (_draws - before))

	# No dice left is just a finished turn, not the state this relic exists for.
	Global.deep_pockets_fired_this_turn = false
	for type: String in Global.DICE_TYPE_ORDER:
		Global.set(type + "_dice_current_amount", 0)
	await _clear_hand()
	before = _draws
	Events.card_played.emit(load(INSIGHT))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("silent when the dice pool is empty", _draws == before, "drew %d" % (_draws - before))

	# And it must not fire while cards remain in hand.
	Global.deep_pockets_fired_this_turn = false
	Global.blue_dice_current_amount = 2
	await _clear_hand()
	_hand.add_card(load(INSIGHT))
	await get_tree().process_frame
	await get_tree().process_frame
	before = _draws
	Events.card_played.emit(load(INSIGHT))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("silent while the hand still holds a card", _draws == before,
			"drew %d, hand %d" % [_draws - before, _hand_size()])

	await _drop_relic(ui)


# --- G: drawing an exhausted deck ---------------------------------------------------------

func _section_g() -> void:
	print("[draw] --- G deck-out ---")
	var stats: CharacterStats = _battle.char_stats
	# Let section F's draws finish first. draw_cards() spaces its callbacks out on a tween, so
	# clearing the hand while one is still running just means the leftovers land a frame later
	# and this section would measure them instead of what it is testing.
	await _await_until(func() -> bool: return false, 1.5)
	await _clear_hand()
	stats.draw_pile.cards.clear()
	stats.discard.cards.clear()

	Events.draw_card.emit(3)
	await _await_until(func() -> bool: return false, 1.2)

	var blanks := 0
	for child in _hand.get_children():
		if child is CardUI and child.card == null:
			blanks += 1
	_check("drawing an empty deck adds no blank card", blanks == 0, "%d blanks" % blanks)
	_check("drawing an empty deck adds nothing at all", _hand_size() == 0, "%d cards" % _hand_size())

	# And it still draws normally once there is something to draw, so the guard is not just
	# turning draw off.
	stats.draw_pile.add_card(load(INSIGHT))
	stats.draw_pile.add_card(load(INSIGHT))
	Events.draw_card.emit(2)
	await _await_until(func() -> bool: return _hand_size() >= 2, 3.0)
	_check("a refilled deck draws again", _hand_size() == 2, "%d cards" % _hand_size())
