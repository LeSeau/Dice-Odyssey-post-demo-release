extends Node

# VERIFICATION harness (2026-08-30) for Julien's report:
#   "I played Dual Cannon and it didn't add a second card socket for red dice."
#
# Drives the REAL path: real battle, real dice.gd, real CardUI, real Events.card_charged.
# debug_red_roll_counts.gd already covers "two socketed cards emit one dice_rolled", but it
# SETS Global.red_socket_capacity = 2 by hand and appends the charged ids itself - it never
# plays the actual card and never goes through _on_card_charged. That is exactly the gap.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_dual_cannon.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
const DUAL_CANNON := "res://characters/warrior/cards/card_dual_cannon.tres"

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _relic_handler: RelicHandler
var _dice: Node
var _hand: Hand
var _played_ids: Array = []
var _last_red_roll := 0
var _rolled_emits: Array = []


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


func _on_card_played(card: Card) -> void:
	_played_ids.append(card.id)


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Global.tutorial_on = true
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	Events.card_played.connect(_on_card_played)
	Events.red_dice_rolled.connect(func() -> void: _last_red_roll = Global.roll_value)
	Events.dice_rolled.connect(func(t: String, v: int) -> void: _rolled_emits.append([t, v]))

	await _boot_battle()
	await _scenario_a_play_on_blue()
	await _scenario_i_mixed_pair()
	await _scenario_b_two_sockets_real_path()
	await _scenario_c_socket2_geometry()
	await _scenario_e_both_cards_play()
	await _scenario_d_switch_away_from_red()
	await _scenario_g_empty_second_socket()
	await _scenario_h_two_single_target()
	await _scenario_f_socket_on_red_then_roll()
	await _scenario_j_order_caption()
	await _scenario_k_socket_2_cancel()
	await _scenario_l_cancel_promotes()
	await _scenario_m_third_card()

	print("\n==== DUAL CANNON: %d checks, %d fail(s) ====" % [checks, fails])
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
	_dice = _battle.find_child("ActiveDice", true, false)
	_hand = _battle.find_child("Hand", true, false) as Hand
	check("battle booted", _dice != null and _hand != null)
	check("Dual Cannon resource loads", load(DUAL_CANNON) != null)
	check("fight starts at red_socket_capacity 1",
			Global.red_socket_capacity == 1, str(Global.red_socket_capacity))


# ---------------------------------------------------------------------------------------
# A. The card played the ordinary way (non-red die, roll meets Min 6).
# ---------------------------------------------------------------------------------------
func _scenario_a_play_on_blue() -> void:
	_section("A. Dual Cannon played on a Blue die")
	var card: Card = (load(DUAL_CANNON) as Card).duplicate()
	print("      requirement=%d number=%d type=%d celestial=%s exhausts=%s" % [
			card.requirement, card.requirement_number, card.type,
			str(card.can_play_without_dice), str(card.exhausts)])

	Global.dice_type = "blue"
	Global.blue_dice_current_amount = 5
	Global.roll_value = 0
	Global.roll_history = []
	Global.next_guaranteed_roll = 6
	_dice.roll_dice()
	await _settle(2.0)
	check("forced a 6 on Blue", Global.roll_value >= 6, str(Global.roll_value))

	check("meets_requirement() true at roll %d" % Global.roll_value,
			card.meets_requirement())

	var player: Node = get_tree().get_first_node_in_group("player")
	check("found player node", player != null)
	var targets: Array[Node] = []
	if player:
		targets.append(player)
	card.play(targets, _battle.char_stats, player.modifier_handler if player else null)
	await _settle(0.4)

	check("capacity raised to 2 by playing the card",
			Global.red_socket_capacity == 2, str(Global.red_socket_capacity))
	var has_status: bool = _player_has_status("dual_cannon")
	check("status badge applied to player", has_status)


# ---------------------------------------------------------------------------------------
# B. THE REPORTED SYMPTOM. Capacity is 2; socket two cards through the real card_charged
#    path and check the first is NOT evicted.
# ---------------------------------------------------------------------------------------
func _scenario_b_two_sockets_real_path() -> void:
	_section("B. Socket two cards on Red (real card_charged path)")
	await _refill_hand(0, 2)
	Events.clear_socket.emit()
	await _settle(0.4)
	Global.dice_type = "red"
	Global.red_dice_current_amount = 3
	Global.charged_card_instance_ids.clear()

	var cards := _socketable_cards(Card.Target.SELF)
	if cards.size() < 2:
		check("two socketable cards in hand", false, str(cards.size()))
		return
	var first: CardUI = cards[0] as CardUI
	var second: CardUI = cards[1] as CardUI

	# Exactly what card_released_state.gd does when you drop a card on the red die.
	Events.card_charged.emit(first)
	Global.charged_card_instance_id = first.card.instance_id
	if not Global.charged_card_instance_ids.has(first.card.instance_id):
		Global.charged_card_instance_ids.append(first.card.instance_id)
	await _settle(0.6)
	check("socket 1 filled", _dice.socketed_card_ui == first,
			str(_dice.socketed_card_ui))

	Events.card_charged.emit(second)
	Global.charged_card_instance_id = second.card.instance_id
	if not Global.charged_card_instance_ids.has(second.card.instance_id):
		Global.charged_card_instance_ids.append(second.card.instance_id)
	await _settle(0.6)

	# If capacity never got raised, _on_card_charged evicts card 1 instead.
	check("socket 1 STILL holds the first card (not evicted)",
			_dice.socketed_card_ui == first,
			"holds %s" % (_dice.socketed_card_ui.card.id
					if is_instance_valid(_dice.socketed_card_ui) else "<null>"))
	check("socket 2 holds the second card",
			_dice.socketed_card_ui_2 == second,
			"holds %s" % (_dice.socketed_card_ui_2.card.id
					if is_instance_valid(_dice.socketed_card_ui_2) else "<null>"))
	check("both ids registered as charged",
			Global.charged_card_instance_ids.size() == 2,
			str(Global.charged_card_instance_ids.size()))


# ---------------------------------------------------------------------------------------
# C. Is socket 2 actually VISIBLE and on screen? A filled-but-invisible socket reads
#    exactly like "it didn't add a second socket".
# ---------------------------------------------------------------------------------------
func _scenario_c_socket2_geometry() -> void:
	_section("C. Socket 2 visibility / geometry")
	var socket: Control = _dice.get("_socket_2") as Control
	if socket == null:
		check("socket 2 node exists", false)
		return
	check("socket 2 node exists", true, socket.name)
	check("socket 2 .visible is true", socket.visible)
	check("socket 2 is visible in tree (no hidden ancestor)",
			socket.is_visible_in_tree())

	var rect := socket.get_global_rect()
	print("      socket1 rect: ", _dice.card_drop_area.get_global_rect())
	print("      socket2 rect: ", rect)
	print("      socket2 modulate: ", socket.modulate,
			"  z_index: ", socket.z_index,
			"  parent: ", socket.get_parent().name)
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	check("socket 2 is inside the 1280x720 design viewport",
			screen.encloses(rect), str(rect))
	check("socket 2 does not overlap socket 1",
			not rect.intersects(_dice.card_drop_area.get_global_rect()))
	check("socket 2 modulate is opaque", socket.modulate.a > 0.9,
			str(socket.modulate.a))

	var texture := socket.get_node_or_null(
			"CardBackground/CardFrame/Panel/ChargedCardTexture") as TextureRect
	check("socket 2 shows a card texture",
			texture != null and texture.texture != null and texture.visible)
	var title := socket.get_node_or_null(
			"CardBackground/CardFrame/CardBanner/Title") as Label
	check("socket 2 shows the card name",
			title != null and title.text != "",
			title.text if title else "<no title node>")


# ---------------------------------------------------------------------------------------
# D. Switching off Red hides socket 1 (card_drop_area). Does socket 2 follow?
# ---------------------------------------------------------------------------------------
func _scenario_d_switch_away_from_red() -> void:
	_section("D. Switching away from Red")
	await _refill_hand(0, 2)
	# Re-fill both sockets: scenario E spent the previous pair, and an already-empty socket 2
	# would make this test pass for the wrong reason.
	Events.clear_socket.emit()
	await _settle(0.4)
	Events.active_dice_changed.emit("red")
	Global.red_dice_current_amount = 3
	Global.charged_card_instance_ids.clear()
	for cu: CardUI in _socketable_cards().slice(0, 2):
		Events.card_charged.emit(cu)
		Global.charged_card_instance_id = cu.card.instance_id
		if not Global.charged_card_instance_ids.has(cu.card.instance_id):
			Global.charged_card_instance_ids.append(cu.card.instance_id)
		await _settle(0.5)
	var socket: Control = _dice.get("_socket_2") as Control
	if socket == null:
		check("socket 2 exists for the switch test", false)
		return
	check("socket 2 is filled before the switch", _dice.socketed_card_ui_2 != null)

	Events.active_dice_changed.emit("blue")
	await _settle(0.6)
	print("      after switch to blue: socket1.visible=%s socket2.visible=%s" % [
			str(_dice.card_drop_area.visible), str(socket.visible)])
	check("socket 1 hidden off Red", not _dice.card_drop_area.visible)
	check("socket 2 ALSO hidden off Red (no ghost card floating)", not socket.visible)

	Events.active_dice_changed.emit("red")
	await _settle(0.6)
	print("      back on red: socket1.visible=%s socket2.visible=%s" % [
			str(_dice.card_drop_area.visible), str(socket.visible)])
	check("socket 1 shown again on Red", _dice.card_drop_area.visible)
	check("socket 2 shown again on Red", socket.visible)


# ---------------------------------------------------------------------------------------
# E. One red roll must resolve BOTH socketed cards.
# ---------------------------------------------------------------------------------------
func _scenario_e_both_cards_play() -> void:
	_section("E. One Red roll plays both socketed cards")
	if _dice.socketed_card_ui == null or _dice.socketed_card_ui_2 == null:
		check("two cards still socketed before the roll", false)
		return
	_played_ids.clear()
	Global.dice_type = "red"
	Global.red_dice_current_amount = 3
	Global.roll_value = 0
	Global.roll_history = []
	print("      before roll: ids=%s socket1=%s socket2=%s" % [
			str(Global.charged_card_instance_ids.size()),
			_dice.socketed_card_ui.card.id, _dice.socketed_card_ui_2.card.id])
	_rolled_emits.clear()
	_dice.roll_dice()
	await _settle(2.5)
	check("two cards played on one Red roll",
			_played_ids.size() == 2, str(_played_ids))
	check("both sockets emptied after the roll",
			_dice.socketed_card_ui == null and _dice.socketed_card_ui_2 == null)
	# The per-roll relics (Blood Sword, House Money, Metronome, Effigy...) must still hear
	# exactly one roll, not one per socketed card.
	check("still exactly one dice_rolled for the roll",
			_rolled_emits.size() == 1, str(_rolled_emits))
	check("playing_red_card released after both resolved",
			not Global.playing_red_card)


# ---------------------------------------------------------------------------------------
# F. The other way the player can reach the card: Dual Cannon SOCKETED on Red, played by
#    the Red roll itself. Needs a 6 on a d6 to clear its own Min 6.
# ---------------------------------------------------------------------------------------
func _scenario_f_socket_on_red_then_roll() -> void:
	_section("F. Dual Cannon socketed on Red, played by the roll")
	Events.clear_socket.emit()
	await _settle(0.4)
	Global.red_socket_capacity = 1
	Global.charged_card_instance_ids.clear()

	var cards := _socketable_cards()
	if cards.is_empty():
		check("a card in hand to reskin as Dual Cannon", false)
		return
	var host_ui: CardUI = cards[0] as CardUI
	host_ui.card = (load(DUAL_CANNON) as Card).duplicate()
	await _settle(0.3)

	Global.dice_type = "red"
	Global.red_dice_current_amount = 3
	Events.card_charged.emit(host_ui)
	Global.charged_card_instance_id = host_ui.card.instance_id
	if not Global.charged_card_instance_ids.has(host_ui.card.instance_id):
		Global.charged_card_instance_ids.append(host_ui.card.instance_id)
	await _settle(0.6)
	check("Dual Cannon sits in socket 1", _dice.socketed_card_ui == host_ui)

	Global.roll_value = 0
	Global.roll_history = []
	Global.next_guaranteed_roll = 6
	_played_ids.clear()
	_dice.roll_dice()
	await _settle(2.5)
	print("      red roll landed on %d, played=%s" % [_last_red_roll, str(_played_ids)])
	check("Red roll was a 6 (Min 6 satisfied)", _last_red_roll >= 6,
			str(_last_red_roll))
	check("Dual Cannon actually played", _played_ids.has("card_second_socket"),
			str(_played_ids))
	check("capacity raised to 2 from the Red socket path",
			Global.red_socket_capacity == 2, str(Global.red_socket_capacity))


# ---------------------------------------------------------------------------------------
# G. THE LIKELY PERCEPTION BUG. Capacity is 2 and the socket is EMPTY - what does the
#    player actually SEE on the Red die? If nothing changes, "it didn't add a socket"
#    is a truthful description of the screen even though the mechanic is live.
# ---------------------------------------------------------------------------------------
func _scenario_g_empty_second_socket() -> void:
	_section("G. Empty socket with capacity 2 - is a second socket VISIBLE?")
	Events.clear_socket.emit()
	await _settle(0.4)
	Events.active_dice_changed.emit("red")
	Global.red_dice_current_amount = 3
	await _settle(0.8)

	check("capacity is still 2", Global.red_socket_capacity == 2,
			str(Global.red_socket_capacity))
	check("socket 1 is visible and empty", _dice.card_drop_area.visible
			and _dice.socketed_card_ui == null)
	var socket: Control = _dice.get("_socket_2") as Control
	var shows_empty_slot: bool = socket != null and socket.visible
	print("      _socket_2 = %s   visible = %s" % [
			str(socket), str(socket.visible) if socket != null else "n/a"])
	# Deliberately asserted as a REQUIREMENT: with the blessing live the player should see
	# somewhere to drop a second card before they own one.
	check("an empty second socket is shown to the player", shows_empty_slot)
	if not shows_empty_slot:
		return
	var req := socket.get_node_or_null(
			"CardBackground/CardFrame/RequirementPanel/RequirementLabel") as Label
	check("empty slot reads as a drop target", req != null and req.text == "Drop a card",
			req.text if req else "<none>")

	# The slot is a runtime duplicate positioned by a hard-coded offset - it has never been
	# laid out against anything. Check it does not land on the hero or the dice row.
	var slot_rect := socket.get_global_rect()
	print("      empty slot rect: ", slot_rect)
	var player: Node = get_tree().get_first_node_in_group("player")
	var sprite := player.get_node_or_null("SpriteRoot") if player else null
	if sprite == null and player:
		sprite = player.find_child("Sprite2D", true, false)
	if sprite != null and sprite is Node2D:
		var sp: Node2D = sprite
		print("      hero origin (screen): ", sp.get_global_transform_with_canvas().origin)
	var row: Node = get_tree().get_first_node_in_group("dice_interface")
	if row != null and row is Control:
		var row_rect: Rect2 = (row as Control).get_global_rect()
		print("      dice row rect: ", row_rect)
		check("empty slot clears the dice slot row", not slot_rect.intersects(row_rect),
				str(row_rect))


# ---------------------------------------------------------------------------------------
# H. Two SINGLE_ENEMY cards socketed. Both CardUIs go to AIMING on the same roll; playing
#    one emits reset_charged_card, which clears BOTH sockets.
# ---------------------------------------------------------------------------------------
func _scenario_h_two_single_target() -> void:
	_section("H. Two single-target cards socketed on one Red roll")
	await _refill_hand(2, 0)
	Events.clear_socket.emit()
	await _settle(0.4)
	Global.charged_card_instance_ids.clear()
	Global.dice_type = "red"
	Global.red_dice_current_amount = 3

	var cards := _socketable_cards(Card.Target.SINGLE_ENEMY)
	if cards.size() < 2:
		check("two single-target cards in hand", false, str(cards.size()))
		return
	var a: CardUI = cards[0] as CardUI
	var b: CardUI = cards[1] as CardUI
	for cu: CardUI in [a, b]:
		Events.card_charged.emit(cu)
		Global.charged_card_instance_id = cu.card.instance_id
		if not Global.charged_card_instance_ids.has(cu.card.instance_id):
			Global.charged_card_instance_ids.append(cu.card.instance_id)
		await _settle(0.5)
	check("both single-target cards socketed",
			_dice.socketed_card_ui == a and _dice.socketed_card_ui_2 == b)

	_played_ids.clear()
	Global.roll_value = 0
	Global.roll_history = []
	_dice.roll_dice()
	await _settle(2.2)
	# Both are now in AIMING waiting on the mouse. Simulate the player releasing the FIRST.
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		check("an enemy to aim at", false)
		return
	var target: Node = enemies[0]
	a.targets.clear()
	a.targets.append(target)
	a.play()
	Events.reset_charged_card.emit()
	Global.playing_red_card = false
	await _settle(1.2)

	print("      after playing card 1: b.visible=%s b.disabled=%s playing_red=%s played=%s" % [
			str(b.visible), str(b.disabled), str(Global.playing_red_card), str(_played_ids)])
	check("the second card was handed to the aim flow, not orphaned",
			b.visible and not b.disabled)
	check("the second card's id is still charged",
			Global.charged_card_instance_ids.has(b.card.instance_id))
	check("playing_red_card still held for the second card", Global.playing_red_card)

	# Finish it the way the player would: pick a target and release.
	b.targets.clear()
	b.targets.append(target)
	b.play()
	Events.reset_charged_card.emit()
	Global.playing_red_card = false
	await _settle(1.2)
	check("both single-target cards ended up played", _played_ids.size() == 2,
			str(_played_ids))


# ---------------------------------------------------------------------------------------
# I. Julien's report: Strike in socket 1, Block in socket 2, one roll -> "it just blocked".
#    The mixed pair is the case the same-target pairs above cannot catch: socket 1's card is
#    single-target (parks in AIMING, emits nothing) while socket 2's is self-targeted, so if
#    socket 2 still resolves off red_dice_rolled it fires FIRST and its reset_charged_card
#    tears down the Strike that is still waiting to be aimed.
# ---------------------------------------------------------------------------------------
func _scenario_i_mixed_pair() -> void:
	_section("I. Strike in socket 1 + Block in socket 2, one Red roll")
	Events.clear_socket.emit()
	await _settle(0.4)
	Global.charged_card_instance_ids.clear()
	Global.dice_type = "red"
	Global.red_dice_current_amount = 3

	var strikes := _socketable_cards(Card.Target.SINGLE_ENEMY)
	var blocks := _socketable_cards(Card.Target.SELF)
	if strikes.is_empty() or blocks.is_empty():
		check("a single-target and a self-target card in hand", false,
				"%d / %d" % [strikes.size(), blocks.size()])
		return
	var strike: CardUI = strikes[0] as CardUI
	var block: CardUI = blocks[0] as CardUI

	for cu: CardUI in [strike, block]:
		Events.card_charged.emit(cu)
		Global.charged_card_instance_id = cu.card.instance_id
		if not Global.charged_card_instance_ids.has(cu.card.instance_id):
			Global.charged_card_instance_ids.append(cu.card.instance_id)
		await _settle(0.5)
	check("Strike in socket 1, Block in socket 2",
			_dice.socketed_card_ui == strike and _dice.socketed_card_ui_2 == block)

	_played_ids.clear()
	_rolled_emits.clear()
	Global.roll_value = 0
	Global.roll_history = []
	_dice.roll_dice()
	await _settle(2.2)
	print("      right after the roll: played=%s strike.visible=%s playing_red=%s" % [
			str(_played_ids), str(strike.visible), str(Global.playing_red_card)])
	# THE BUG: the Block resolved on its own and nothing is waiting to be aimed.
	check("nothing resolved before the player aims", _played_ids.is_empty(),
			str(_played_ids))
	check("the Strike is still the one in socket 1, waiting to be aimed",
			_dice.socketed_card_ui == strike)
	check("the roll is still held for the aim", Global.playing_red_card)

	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		check("an enemy to aim at", false)
		return
	var strike_card_id: String = strike.card.id
	strike.targets.clear()
	strike.targets.append(enemies[0])
	strike.play()
	Events.reset_charged_card.emit()
	Global.playing_red_card = false
	await _settle(1.4)
	print("      after aiming the Strike: played=%s" % str(_played_ids))
	check("both the Strike and the Block resolved", _played_ids.size() == 2,
			str(_played_ids))
	check("the Strike went first", not _played_ids.is_empty()
			and _played_ids[0] == strike_card_id, str(_played_ids))
	check("one dice_rolled for the whole roll", _rolled_emits.size() == 1,
			str(_rolled_emits))


# ---------------------------------------------------------------------------------------
# J. The captions that say which socket resolves first.
# ---------------------------------------------------------------------------------------
func _scenario_j_order_caption() -> void:
	_section("J. Play-order captions")
	Events.clear_socket.emit()
	await _settle(0.4)
	Events.active_dice_changed.emit("red")
	Global.red_dice_current_amount = 3
	await _settle(0.8)

	var one := _order_caption(_dice.card_drop_area)
	var socket2: Control = _dice.get("_socket_2") as Control
	var two := _order_caption(socket2) if socket2 != null else null
	print("      socket1 caption: %s | socket2 caption: %s" % [
			one.text if one else "<none>", two.text if two else "<none>"])
	check("socket 1 is captioned", one != null and one.visible and one.text != "")
	check("socket 2 is captioned", two != null and two.visible and two.text != "")
	if one == null or two == null:
		return
	check("the captions differ", one.text != two.text)
	# Measured, not eyeballed: the band is 140px wide and the caption must not wrap out of it.
	var font := one.get_theme_font("font")
	var size := one.get_theme_font_size("font_size")
	for label: Label in [one, two]:
		var w: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		print("      \"%s\" renders %.1fpx of the 140px band" % [label.text, w])
		var budget: float = label.offset_right - label.offset_left
		check("caption fits the space left of the cancel button", w <= budget,
				"%.1f in %.1f" % [w, budget])
	var cancel_panel := _dice.card_drop_area.get_node_or_null(
			"CancelRedCardPanel") as Control
	if cancel_panel:
		var cap_rect := Rect2(one.offset_left, one.offset_top,
				one.offset_right - one.offset_left, one.offset_bottom - one.offset_top)
		var x_rect := Rect2(cancel_panel.offset_left, cancel_panel.offset_top,
				cancel_panel.offset_right - cancel_panel.offset_left,
				cancel_panel.offset_bottom - cancel_panel.offset_top)
		print("      caption %s vs cancel button %s" % [str(cap_rect), str(x_rect)])
		check("caption does not run under the cancel button",
				not cap_rect.intersects(x_rect))
	check("caption clears the description panel",
			one.offset_top >= _dice.description_panel.offset_bottom,
			"%.0f vs %.0f" % [one.offset_top, _dice.description_panel.offset_bottom])

	# And it must disappear when the blessing is not up.
	Global.red_socket_capacity = 1
	Events.active_dice_changed.emit("red")
	await _settle(0.7)
	check("caption hidden without Dual Cannon", not _order_caption(_dice.card_drop_area).visible)
	Global.red_socket_capacity = 2


func _order_caption(socket: Control) -> Label:
	if socket == null:
		return null
	return socket.get_node_or_null(
			"CardBackground/CardFrame/SocketOrderLabel") as Label


# ---------------------------------------------------------------------------------------
# K. Socket 2 has its own X, and it only removes socket 2's card.
# ---------------------------------------------------------------------------------------
func _scenario_k_socket_2_cancel() -> void:
	_section("K. Socket 2's own cancel button")
	var pair := await _socket_two_cards()
	if pair.is_empty():
		return
	var first: CardUI = pair[0]
	var second: CardUI = pair[1]
	var socket: Control = _dice.get("_socket_2") as Control
	var cancel := socket.get_node_or_null("CancelRedCardPanel") as Control
	check("socket 2 shows a cancel button when filled", cancel != null and cancel.visible)

	var button := socket.get_node_or_null(
			"CancelRedCardPanel/CancelRedCard") as BaseButton
	check("socket 2's X is not wired to socket 1's handler",
			button != null
			and not button.pressed.is_connected(_dice._on_cancel_red_card_pressed))

	button.pressed.emit()
	await _settle(0.6)
	check("socket 2 emptied", _dice.socketed_card_ui_2 == null)
	check("socket 1 untouched", _dice.socketed_card_ui == first)
	check("the cancelled card is back in hand", second.visible and not second.disabled)
	check("only socket 1's card is still charged",
			Global.charged_card_instance_ids == [first.card.instance_id],
			str(Global.charged_card_instance_ids.size()))
	check("socket 2 falls back to the empty slot",
			socket.visible and not (cancel.visible))


# ---------------------------------------------------------------------------------------
# L. Socket 1's X hands back only its own card; socket 2's slides up and still plays.
# ---------------------------------------------------------------------------------------
func _scenario_l_cancel_promotes() -> void:
	_section("L. Cancelling socket 1 promotes socket 2")
	var pair := await _socket_two_cards()
	if pair.is_empty():
		return
	var first: CardUI = pair[0]
	var second: CardUI = pair[1]
	var second_id: String = second.card.id

	_dice._on_cancel_red_card_pressed()
	await _settle(0.8)
	check("socket 1's card is back in hand", first.visible and not first.disabled)
	check("socket 2's card moved into socket 1", _dice.socketed_card_ui == second,
			"holds %s" % (_dice.socketed_card_ui.card.id
					if is_instance_valid(_dice.socketed_card_ui) else "<null>"))
	check("socket 2 is empty again", _dice.socketed_card_ui_2 == null)
	check("only the promoted card is charged",
			Global.charged_card_instance_ids == [second.card.instance_id],
			str(Global.charged_card_instance_ids))

	# And it still resolves - a promoted card whose id was dropped would silently no-op.
	_played_ids.clear()
	Global.roll_value = 0
	Global.roll_history = []
	_dice.roll_dice()
	await _settle(2.2)
	check("the promoted card plays on the roll", _played_ids == [second_id],
			str(_played_ids))


# ---------------------------------------------------------------------------------------
# M. A third card replaces socket 2, so the longest-waiting card keeps "played first".
# ---------------------------------------------------------------------------------------
func _scenario_m_third_card() -> void:
	_section("M. Dropping a third card")
	var pair := await _socket_two_cards()
	if pair.is_empty():
		return
	var first: CardUI = pair[0]
	var second: CardUI = pair[1]
	await _refill_hand(0, 1)
	var spare: Array = []
	for cu: CardUI in _socketable_cards():
		if cu != first and cu != second and cu.visible:
			spare.append(cu)
	if spare.is_empty():
		check("a third card to drop", false)
		return
	var third: CardUI = spare[0] as CardUI

	Events.card_charged.emit(third)
	await _settle(0.7)
	check("socket 1 still holds the first card", _dice.socketed_card_ui == first,
			"holds %s" % (_dice.socketed_card_ui.card.id
					if is_instance_valid(_dice.socketed_card_ui) else "<null>"))
	check("the third card took socket 2", _dice.socketed_card_ui_2 == third)
	check("the displaced card is back in hand", second.visible and not second.disabled)
	check("the displaced card is no longer charged",
			not Global.charged_card_instance_ids.has(second.card.instance_id))


# Socket two fresh cards and hand them back. Returns [] (after logging a fail) if the hand
# cannot supply them, so the caller can bail instead of asserting against nulls.
func _socket_two_cards() -> Array:
	Events.clear_socket.emit()
	await _settle(0.5)
	Events.active_dice_changed.emit("red")
	Global.red_dice_current_amount = 3
	Global.charged_card_instance_ids.clear()
	await _refill_hand(1, 1)
	var cards := _socketable_cards()
	if cards.size() < 2:
		check("two cards to socket", false, str(cards.size()))
		return []
	var out: Array = []
	for cu: CardUI in cards.slice(0, 2):
		Events.card_charged.emit(cu)
		Global.charged_card_instance_id = cu.card.instance_id
		if not Global.charged_card_instance_ids.has(cu.card.instance_id):
			Global.charged_card_instance_ids.append(cu.card.instance_id)
		await _settle(0.5)
		out.append(cu)
	if _dice.socketed_card_ui != out[0] or _dice.socketed_card_ui_2 != out[1]:
		check("both sockets filled for the test", false)
		return []
	return out


# ---------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------
func _player_has_status(status_id: String) -> bool:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var handler: Node = player.get("status_handler")
	if handler == null:
		return false
	for child in handler.get_children():
		var s: Node = child
		var st: Status = s.get("status")
		if st != null and st.id == status_id:
			return true
	return false


func _socketable_cards(only_target: int = -1) -> Array:
	var out: Array = []
	for child in _hand.get_children():
		var cu := child as CardUI
		if cu == null or cu.card == null:
			continue
		if cu.card.can_play_without_dice:
			continue
		if only_target != -1 and cu.card.target != only_target:
			continue
		out.append(cu)
	return out


# Scenarios consume cards, and a scenario that silently runs out tests nothing. Top the hand
# back up through the real Hand.add_card() path (fresh Card duplicates, so fresh instance_ids).
func _refill_hand(single_target: int, self_target: int) -> void:
	var wanted: Array[String] = []
	for i: int in range(single_target):
		wanted.append("res://characters/warrior/cards/warrior_axe_attack1.tres")
	for i: int in range(self_target):
		wanted.append("res://characters/warrior/cards/warrior_block1.tres")
	for path: String in wanted:
		var src: Card = load(path) as Card
		if src == null:
			continue
		var copy: Card = src.duplicate()
		copy.instance_id = randi()
		_hand.add_card(copy)
		await get_tree().process_frame
	await _settle(0.5)


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _await_until(predicate: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
