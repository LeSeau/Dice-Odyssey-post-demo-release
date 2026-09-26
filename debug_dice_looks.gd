extends Node

# Harness for the 2026-09-24 dice look pass (Julien: "lets try 4 5 6 9 10 11 12"):
#   A  blank face when nothing is rolled (spend, switch, Red's 1s read delay, Reservoir)
#   B  the die goes dormant once its type AND its banked Power are spent (lit while Power waits,
#      delay after the spend, tint, ring speed, charge wake on the absorb, switch wake, Ricochet
#      at 0 Power, Mech, Red's read delay)
#   C  a switch pops the big die at once, with no mini die from the slot (removed 2026-09-25),
#      and a roll right after a switch leaves it at rest
#   D  End Turn drains the tray (display only, Golem glint, no nudge, dormant enemy turn,
#      refill, blank face at the new turn)
#   E  red suspense: the ribbon verdict and the Power projection against the Power the card
#      REALLY resolves on (Blood Sword, Weak, Boost, Surge, Dice Echo, Buzzer Shot, a bank),
#      and the controls where no suspense may play (guaranteed face, Ink, no requirement)
#   F  the click rattle and the landing knock load and are short enough
#   G  every face-drawing node samples its mipmaps
#   H  nothing is left behind (ghosts, pickup flights, suspense tweens)
#
# Boots the real battle.tscn (recipe from debug_red_roll_order.gd). Headless is fine: nothing
# here reads pixels.
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_dice_looks.tscn --headless
# Env: DICE_LOOKS_ONLY="A,E" runs the listed sections only.

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
const AEGIS := "res://characters/warrior/cards/card_aegis.tres"      # SELF, Mult 6
const BLOCK := "res://characters/warrior/cards/warrior_block1.tres"  # SELF, no requirement
const BLOOD_SWORD := "res://relics/blood_sword.tres"
const WEAK := "res://statuses/weak.tres"
const DICE_ECHO := "res://statuses/status_opening_gambit.tres"
const BUZZER_SHOT := "res://statuses/status_coiled_spring.tres"
const SOUNDS: Array[String] = ["res://sounds/dice_land_knock_1.wav", "res://sounds/dice_land_knock_2.wav",
		"res://sounds/dice_roll_shake_1.wav", "res://sounds/dice_roll_shake_2.wav",
		"res://sounds/dice_roll_shake_3.wav"]
const SLOT_DEPLETED := Color(0.32, 0.32, 0.32, 0.55)

var checks := 0
var fails := 0
var hands_drawn := 0
var _only := ""
var _clock := 0.0            # game seconds (scaled by hit-stop, like everything under test)
var _battle: Battle
var _dice: Node
var _iface: Node
var _hand: Hand
var _relic_handler: RelicHandler
var _delivered_at := -1.0
var _played_power := -1
var _played_face := -1
var _tints_at_play := -1
var _ribbon_at_play := Color(0, 0, 0, 0)


func _process(delta: float) -> void:
	_clock += delta


func _ready() -> void:
	_only = OS.get_environment("DICE_LOOKS_ONLY").to_upper().replace(" ", "")
	Events.player_hand_drawn.connect(_on_hand_drawn)
	Events.dice_charge_delivered.connect(_on_charge_delivered_probe)
	Events.card_played.connect(_on_card_played_probe)
	await _boot()
	if _dice == null or _iface == null:
		print("\n==== DICE LOOKS: boot failed ====")
		get_tree().quit(1)
		return
	if OS.get_environment("DICE_LOOKS_REEL") == "1":
		await _reel()
		get_tree().quit(0)
		return
	if _run("A"):
		await _section_a()
	if _run("B"):
		await _section_b()
	if _run("C"):
		await _section_c()
	if _run("D"):
		await _section_d()
	if _run("E"):
		await _section_e()
	if _run("F"):
		_section_f()
	if _run("G"):
		_section_g()
	await _section_h()
	print("\n==== DICE LOOKS: %d checks, %d fail(s) ====" % [checks, fails])
	print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
	get_tree().quit(1 if fails > 0 else 0)


func _run(section: String) -> bool:
	return _only == "" or section in _only.split(",")


func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("[dice-looks] PASS  ", label, "  ", detail)
	else:
		fails += 1
		print("[dice-looks] FAIL  ", label, "  ", detail)


# ------------------------------------------------------------------------------------ boot

func _boot() -> void:
	Global.reset_run_state()
	Global.tutorial_on = false
	Global.tutorial_reset_power_warning = false
	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(_battle)
	_relic_handler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(_relic_handler)
	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	# Dead Weight pays Surge +1 WHILE HELD: whether it lands in the opening hand would shift
	# every Power number in E by one (the debug_red_roll_order.gd lesson).
	var clean: Array[Card] = []
	for c: Card in _battle.char_stats.deck.cards:
		if not c.id.begins_with("card_dead_weight"):
			clean.append(c)
	_battle.char_stats.deck.cards = clean
	_battle.relics = _relic_handler
	_battle.battle_stats = load(FIGHT)
	_battle.act_tier = 1
	_relic_handler.add_relic(load(BLOOD_SWORD))
	_battle.start_battle()
	await _until(func() -> bool: return hands_drawn > 0, 20.0)
	_dice = _battle.get_node_or_null("ActiveDice")
	_iface = _battle.get_node_or_null("DiceInterface")
	_hand = _battle.find_child("Hand", true, false) as Hand
	# Tough enemies: nothing here should end the fight.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.stats.max_health = 999
		e.stats.health = 999
	await _wait(0.5)


func _on_hand_drawn() -> void:
	hands_drawn += 1


func _on_charge_delivered_probe(_type: String, _count: int) -> void:
	_delivered_at = _clock


# What the socketed card resolves on: Card.play() emits card_played on its first line, after
# every roll listener (Blood Sword, Dice Echo, Buzzer Shot, Sixth Gear) has run.
func _on_card_played_probe(_card: Card) -> void:
	_played_power = int(Global.roll_value)
	_played_face = int(Global.last_roll)
	_tints_at_play = get_tree().get_nodes_in_group("red_suspense_tint").size()
	if _dice != null and is_instance_valid(_dice.requirement_panel):
		_ribbon_at_play = _dice.requirement_panel.modulate


# ---------------------------------------------------------------------------------- helpers

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _until(cond: Callable, timeout_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _landed() -> void:
	await _until(func() -> bool: return not _dice._roll_in_progress, 4.0)


func _roll(face: int) -> void:
	Global.tutorial_forced_rolls = [face]
	_dice.roll_dice()


func _click_slot(index: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	_iface.call("_on_dice_%d_gui_input" % index, ev)


func _tex_path() -> String:
	var tex: Texture2D = _dice.dice_display.texture
	return tex.resource_path if tex != null else "<null>"


func _panel() -> CanvasItem:
	return _dice.dice_display.get_parent() as CanvasItem


func _close(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


func _status_handler() -> StatusHandler:
	return Global._player_status_handler()


func _enemy() -> Node:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			return e
	return null


# ------------------------------------------------------------------------ A: blank face

func _section_a() -> void:
	print("\n--- A: the die is blank until something is rolled ---")
	Global.blue_dice_current_amount = 5
	check("A1 an unrolled die shows the blank face", _tex_path() == "res://assets/images/blue_blank.png", _tex_path())
	_roll(4)
	await _landed()
	check("A2 a roll shows its face", _tex_path() == "res://assets/images/blue4.png", _tex_path())
	check("A2b control: the rolled die does not count as blank", not _dice._die_is_blank())
	Events.dice_roll_reset.emit()
	await get_tree().process_frame
	check("A3 a card spending the Power clears the face", _dice._die_is_blank(), _tex_path())
	var ghosts := get_tree().get_nodes_in_group("die_face_clear_ghost")
	var ghost_tex := ""
	if ghosts.size() == 1:
		var g := ghosts[0] as TextureRect
		ghost_tex = g.texture.resource_path if g.texture != null else "<null>"
	check("A3b ...through a fading ghost of the old face", ghosts.size() == 1 and ghost_tex.ends_with("blue4.png"),
			"%d ghost(s) %s" % [ghosts.size(), ghost_tex])
	await _wait(0.4)
	check("A4 the ghost frees itself", get_tree().get_nodes_in_group("die_face_clear_ghost").is_empty())

	# Reservoir keeps a floor of Power through a spend, so the roll it came from stays shown.
	Global.power_kept_on_reset = 2
	_roll(6)
	await _landed()
	Events.dice_roll_reset.emit()
	await get_tree().process_frame
	check("A5 control: Power kept through a spend keeps its face", _tex_path().ends_with("blue6.png")
			and int(Global.roll_value) == 2, "%s power %d" % [_tex_path(), int(Global.roll_value)])
	Global.power_kept_on_reset = 0
	Events.dice_roll_reset.emit()
	await _wait(0.3)

	Global.red_dice_current_amount = 2
	_click_slot(2)
	await _wait(0.3)
	check("A6 switching shows the new type's blank face", _tex_path() == "res://assets/images/red_blank.png", _tex_path())
	# A landed Red result, then the socketed card's spend: Red wipes after a 1s read delay.
	_dice.dice_display.texture = load("res://assets/images/red4.png")
	Global.roll_value = 4
	Global.roll_history = [4]
	Events.dice_roll_reset.emit()
	await _wait(0.5)
	check("A7 Red keeps the face through its read delay", _tex_path().ends_with("red4.png"), _tex_path())
	await _wait(0.8)
	check("A7b ...then goes blank", _tex_path() == "res://assets/images/red_blank.png", _tex_path())
	Global.blue_dice_current_amount = 5
	_click_slot(1)
	await _wait(0.3)


# ------------------------------------------------------------------------ B: dormant die

func _section_b() -> void:
	print("\n--- B: a spent die goes dormant ---")
	Global.blue_dice_current_amount = 1
	Events.dice_amount_changed.emit()
	_roll(3)
	await _landed()
	await _wait(0.1)
	check("B1 the last die's landing plays at full light", not _dice._dormant)
	await _wait(1.0)
	# Out of dice, but that roll's Power is still to spend (Julien, 2026-09-25 playtest).
	check("B1b out of dice with its Power still banked: it stays lit", not _dice._dormant,
			"power %d" % int(Global.roll_value))
	Events.dice_roll_reset.emit()
	await _wait(0.2)
	check("B1c a card spends that Power: no dim on the spend itself", not _dice._dormant)
	await _wait(0.8)
	var panel := _panel()
	check("B2 ...then dormant once the Power is spent", _dice._dormant)
	check("B2b ...dimmed to the dormant tint", _close(panel.modulate, _dice.DORMANT_TINT, 0.03), str(panel.modulate))
	check("B3 the emanation (the Power light) is not under the dimmed panel",
			not panel.is_ancestor_of(_dice.emanation))
	var mat := _dice.aura.material as ShaderMaterial
	var speed: float = float(mat.get_shader_parameter("wave_speed")) if mat != null else -1.0
	var target_speed: float = _dice._aura_wave_speed_target()
	var dormant_speed: float = _dice._dormant_speed
	check("B4 the ring slows while dormant", absf(dormant_speed - float(_dice.DORMANT_SPEED_MULT)) < 0.01
			and absf(speed - target_speed) < 0.01, "speed %.3f target %.3f mult %.2f" % [speed, target_speed, dormant_speed])

	# A charge into the empty active die: dark while the dice fly, awake on the absorb flash.
	_delivered_at = -1.0
	Global.blue_dice_current_amount += 1
	Events.dice_charged.emit("blue", 1)
	var charged_at := _clock
	await _wait(0.3)
	var in_flight: int = int(_dice._charges_in_flight.get("blue", 0))
	check("B5 it stays dark while the charge is in the air", _dice._dormant, "%d in flight" % in_flight)
	var woke_at := -1.0
	var wake_modulate := Color.BLACK
	var t0 := _clock
	while _clock - t0 < 2.5:
		await get_tree().process_frame
		if woke_at < 0.0 and not _dice._dormant:
			woke_at = _clock
			wake_modulate = panel.modulate
	check("B5b ...and wakes only after the delivery, on the absorb beat", woke_at > 0.0 and _delivered_at > 0.0
			and woke_at >= _delivered_at + 0.15, "delivered +%.2fs, woke +%.2fs" % [_delivered_at - charged_at, woke_at - charged_at])
	check("B5c ...without a second flash on top of the absorb", _close(wake_modulate, Color.WHITE, 0.02), str(wake_modulate))

	_roll(2)
	await _landed()
	Events.dice_roll_reset.emit()
	await _wait(1.0)
	check("B6 pre: dormant again once that die and its Power are spent", _dice._dormant)
	Global.red_dice_current_amount = 1
	_click_slot(2)
	var peak := 0.0
	for i in 8:
		await get_tree().process_frame
		peak = maxf(peak, panel.modulate.r)
	check("B6 switching to a type with dice wakes it, with a flash", not _dice._dormant and peak > 1.2, "peak %.2f" % peak)

	# Ricochet: a last roll that came to 0 Power (Weak ate it, say) stays lit while its reroll is
	# still available. Banked Power alone would keep it lit, so the Power is zeroed first.
	Global.odd_dice_max_amount = maxi(int(Global.odd_dice_max_amount), 1)
	Global.odd_dice_current_amount = 1
	_iface.initialize_dices()
	_click_slot(7)
	await _wait(0.3)
	_roll(5)
	await _landed()
	await _wait(0.3)
	Global.roll_value = 0
	await _wait(1.1)
	var can_reroll: bool = _dice._can_ricochet_reroll()
	check("B7 Ricochet: a last roll at 0 Power stays lit while its reroll is available", not _dice._dormant and can_reroll,
			"reroll %s power %d" % [str(can_reroll), int(Global.roll_value)])
	_dice._on_ricochet_reroll_pressed()
	await _landed()
	Events.dice_roll_reset.emit()
	await _wait(1.1)
	check("B7b ...and sleeps once the reroll and its Power are spent", _dice._dormant)

	# Mech: its +-1 needs banked Power, so the Power rule is what keeps it lit.
	Global.mech_dice_max_amount = maxi(int(Global.mech_dice_max_amount), 1)
	Global.mech_dice_current_amount = 1
	_iface.initialize_dices()
	_click_slot(9)
	await _wait(0.3)
	_roll(4)
	await _landed()
	await _wait(1.1)
	check("B8 Mech: the last die stays lit while its +-1 is available", not _dice._dormant)
	_dice._on_mech_increase_pressed()
	await _wait(1.1)
	check("B8b ...and after the +-1, with its Power still banked", not _dice._dormant,
			"power %d" % int(Global.roll_value))
	Events.dice_roll_reset.emit()
	await _wait(1.1)
	check("B8c ...then sleeps once that Power is spent", _dice._dormant)

	# Red: the socketed card spends the Power at landing, but the number holds through Red's 1s
	# read delay before it clears. The die follows the number.
	Global.red_dice_current_amount = 1
	_click_slot(2)
	await _wait(0.3)
	Global.red_dice_current_amount = 0
	Global.roll_value = 4
	Global.roll_history = [4]
	Events.dice_roll_reset.emit()
	await _wait(0.8)
	check("B10 Red: lit through the 1s read delay while its number still shows", not _dice._dormant,
			"power %d" % int(Global.roll_value))
	await _wait(1.2)
	check("B10b ...then dormant once the number clears", _dice._dormant, "power %d" % int(Global.roll_value))

	Global.odd_dice_max_amount = 0
	Global.odd_dice_current_amount = 0
	Global.mech_dice_max_amount = 0
	Global.mech_dice_current_amount = 0
	Global.blue_dice_current_amount = 5
	_iface.initialize_dices()
	_click_slot(1)
	await _wait(0.5)
	check("B9 back on a type with dice: awake", not _dice._dormant)


# ------------------------------------------------------------------ C: switching type
# The mini die that fell from the slot into the big die was removed on 2026-09-25 (Julien:
# "kinda noise"). A switch is the big die's own pop again, at once, with no give-way first.

func _section_c() -> void:
	print("\n--- C: a switch pops the big die at once, no mini die ---")
	Global.red_dice_current_amount = 1
	Events.dice_amount_changed.emit()
	await _wait(0.2)
	_click_slot(2)
	var flights := get_tree().get_nodes_in_group("dice_pickup_flight").size()
	var min_scale := 9.0
	var early_max := 0.0
	var t0 := _clock
	while _clock - t0 < 0.5:
		await get_tree().process_frame
		var sx: float = _dice.dice_display.scale.x
		min_scale = minf(min_scale, sx)
		if _clock - t0 <= 0.1:
			early_max = maxf(early_max, sx)
	check("C1 clicking a slot launches no mini die", flights == 0 and not _iface.has_method("_begin_pickup"),
			"%d flight(s)" % flights)
	check("C2 the big die pops at once, without giving way first", early_max > 1.05 and min_scale > 0.95,
			"max in the first 0.1s %.2f, min %.2f" % [early_max, min_scale])
	var final_scale: Vector2 = _dice.dice_display.scale
	check("C3 ...and comes back to rest", final_scale.is_equal_approx(Vector2.ONE), str(final_scale))

	# A roll right after a switch owns the die's scale.
	Global.blue_dice_current_amount = 3
	_click_slot(1)
	_roll(2)
	await _landed()
	await _wait(0.8)
	final_scale = _dice.dice_display.scale
	check("C4 a roll right after a switch: die back at rest", final_scale.is_equal_approx(Vector2.ONE), str(final_scale))
	Events.dice_roll_reset.emit()
	await _wait(0.3)


# ----------------------------------------------------------------------- D: End Turn drain

func _section_d() -> void:
	print("\n--- D: End Turn drains the dice that are lost ---")
	# A face on the die, so the new turn has something to clear (D8).
	Global.blue_dice_current_amount = 3
	_roll(3)
	await _landed()
	check("D0a pre: the die shows the rolled face", not _dice._die_is_blank(), _tex_path())
	Global.blue_dice_current_amount = 2
	Global.red_dice_current_amount = 1
	Global.even_dice_max_amount = maxi(int(Global.even_dice_max_amount), 1)
	Global.even_dice_current_amount = 1
	_iface.initialize_dices()
	_iface._on_dice_amount_changed()
	await _wait(0.3)
	var blue_label: Label = _iface.dice_1_label
	var even_label: Label = _iface.dice_6_label
	var blue_slot: Control = _iface.dice_1
	check("D0 pre: Blue shows its dice", blue_label.text.begins_with("2/"), blue_label.text)
	var hands_before := hands_drawn
	_battle.battle_ui._on_end_turn_button_pressed()
	await get_tree().process_frame
	var blue_live: int = int(Global.blue_dice_current_amount)
	check("D1 display only: the live counts are untouched", blue_live == 2, "blue %d" % blue_live)
	var glint := 0.0
	var t0 := _clock
	while _clock - t0 < 0.6:
		await get_tree().process_frame
		glint = maxf(glint, even_label.modulate.r)
	check("D2 the lost Blue dice drain to 0", blue_label.text.begins_with("0/"), blue_label.text)
	check("D2b ...and their slot greys out", _close(blue_slot.modulate, SLOT_DEPLETED, 0.05), str(blue_slot.modulate))
	check("D3 the Golem die carries over: its count stays", even_label.text.begins_with("1/"), even_label.text)
	check("D3b ...with a warm glint", glint > 1.3, "label r %.2f" % glint)
	var nudges: Array = _iface._nudge_nodes
	check("D4 no 'switch to me' nudge through the enemy turn", nudges.is_empty(), "%d" % nudges.size())
	# A count update during the enemy turn (a theft, a hostage) refreshes every label: the
	# drained dice must not come back onto the tray.
	Events.dice_amount_changed.emit()
	await get_tree().process_frame
	check("D4b a count update mid enemy turn keeps them drained", blue_label.text.begins_with("0/")
			and even_label.text.begins_with("1/"), "%s / %s" % [blue_label.text, even_label.text])
	await _wait(0.5)
	check("D5 the die goes dark for the enemy turn", _dice._dormant)
	await _until(func() -> bool: return hands_drawn > hands_before, 25.0)
	await _wait(0.4)
	var drained: bool = _iface._tray_drained
	check("D6 the refill brings the tray back", not drained and not blue_label.text.begins_with("0/")
			and not _close(blue_slot.modulate, SLOT_DEPLETED, 0.05), "%s %s" % [blue_label.text, str(blue_slot.modulate)])
	check("D6b the Golem carry arrived", int(Global.even_dice_current_amount) == 2, "even %d" % int(Global.even_dice_current_amount))
	check("D7 the die wakes with the new turn", not _dice._dormant)
	check("D8 a new turn with nothing banked starts on the blank face", _dice._die_is_blank(), _tex_path())
	Global.even_dice_max_amount = 0
	Global.even_dice_current_amount = 0
	_iface.initialize_dices()


# ----------------------------------------------------------------------- E: red suspense

func _section_e() -> void:
	print("\n--- E: red suspense tells the truth ---")
	# Face 4 + Blood Sword 2 = 6 (Mult 6 passes); face 6 + 2 = 8 fails.
	await _red_case("E1 Blood Sword", 4, {})
	await _red_case("E2 a failing face", 6, {})
	await _red_case("E3 Weak 1", 5, {"weak": 1})
	await _red_case("E4 Boost 3", 1, {"boost": 3})
	await _red_case("E5 Surge 2", 2, {"surge": 2})
	await _red_case("E6 Dice Echo", 2, {"echo": true})
	# Buzzer Shot triples the face: 3f + 2 is never a multiple of 6, so no face can pass.
	await _red_case("E7 control: Buzzer Shot, no face can pass", 1, {"buzzer": true}, false)
	await _red_case("E8 3 Power already banked", 1, {"bank": 3})
	await _red_case("E9 control: a guaranteed face (Scout, Lucky)", 4, {"guaranteed": true}, false)
	await _red_case("E10 control: under Ink", 4, {"ink": true}, false)
	await _red_case("E11 control: a card with no requirement", 3, {}, false, BLOCK)


func _socket(path: String) -> CardUI:
	Events.clear_socket.emit()
	await _wait(0.4)
	Global.charged_card_instance_ids.clear()
	var card := (load(path) as Card).duplicate() as Card
	_hand.add_card(card)
	await _wait(0.6)
	var ui: CardUI = null
	for c in _hand.get_children():
		if c is CardUI and (c as CardUI).card == card:
			ui = c
	if ui == null:
		return null
	Global.red_dice_current_amount = 3
	if Global.dice_type != "red":
		_click_slot(2)
		await _wait(0.4)
	Global.red_socket_capacity = 1
	ui.targets.clear()
	var enemy := _enemy()
	if enemy != null:
		ui.targets.append(enemy)
	Events.card_charged.emit(ui)
	Global.charged_card_instance_id = ui.card.instance_id
	if not Global.charged_card_instance_ids.has(ui.card.instance_id):
		Global.charged_card_instance_ids.append(ui.card.instance_id)
	await _wait(0.6)
	return ui


func _red_case(label: String, face: int, mods: Dictionary, expect_suspense: bool = true,
		card_path: String = AEGIS) -> void:
	var ui := await _socket(card_path)
	if ui == null or _dice.socketed_card_ui != ui:
		check(label + ": the card is socketed", false)
		return
	var handler := _status_handler()
	# Isolation: a Red whiff emits no reset, so the previous case's Power would still be banked,
	# and the Satyr's enemy turn in D puts Weak on the hero.
	Global.roll_value = 0
	Global.roll_history = []
	var enemy_weak := handler._get_status("weak")
	if enemy_weak != null:
		enemy_weak.stacks = 0
	if mods.has("weak"):
		var weak := (load(WEAK) as Status).duplicate() as Status
		weak.stacks = int(mods["weak"])
		handler.add_status(weak)
	if mods.has("boost"):
		Global.next_roll_modifier = int(mods["boost"])
	if mods.has("surge"):
		Global.surge_amount = int(mods["surge"])
	if mods.has("echo"):
		var echo := handler._get_status("dice_echo")
		if echo == null:
			handler.add_status((load(DICE_ECHO) as Status).duplicate() as Status)
			echo = handler._get_status("dice_echo")
		echo.set("triggered_this_turn", false)
	if mods.has("buzzer"):
		handler.add_status((load(BUZZER_SHOT) as Status).duplicate() as Status)
		var spring := handler._get_status("buzzer_shot")
		spring.set("_armed", true)
	if mods.has("bank"):
		Global.roll_value = int(mods["bank"])
	if mods.has("ink"):
		Global.ink_active = true
	if mods.has("guaranteed"):
		Global.next_guaranteed_roll = face
	else:
		Global.tutorial_forced_rolls = [face]

	var projected: int = _dice._projected_red_power(face)
	var predicted_pass: bool = _dice._face_passes(ui.card, face)
	var block_before: int = int(Global.player.stats.block)
	_played_power = -1
	_ribbon_at_play = Color(0, 0, 0, 0)
	_dice.roll_dice()
	var saw_suspense := false
	var seen_pass := false
	var seen_fail := false
	var last_tint := Color(0, 0, 0, 0)
	var t0 := _clock
	while _clock - t0 < 1.6:
		await get_tree().process_frame
		if _dice._red_suspense:
			saw_suspense = true
		for n in get_tree().get_nodes_in_group("red_suspense_tint"):
			var c: Color = (n as ColorRect).color
			last_tint = c
			if c.is_equal_approx(_dice.RED_SUSPENSE_PASS_COLOR):
				seen_pass = true
			elif c.is_equal_approx(_dice.RED_SUSPENSE_FAIL_COLOR):
				seen_fail = true
	var gained: int = int(Global.player.stats.block) - block_before

	check(label + ": the projection is the Power the card resolves on", projected == _played_power,
			"projected %d, resolved on %d (face %d, Blood Sword %s)" % [projected, _played_power,
			_played_face, str(_dice._owns_relic("blood_sword"))])
	check(label + ": the ribbon's verdict is the card's outcome", predicted_pass == (gained > 0),
			"predicted %s, gained %d Block" % [str(predicted_pass), gained])
	if expect_suspense:
		check(label + ": suspense flashed both verdicts on the ribbon", saw_suspense and seen_pass and seen_fail,
				"pass %s fail %s" % [str(seen_pass), str(seen_fail)])
		var last_was_pass: bool = last_tint.is_equal_approx(_dice.RED_SUSPENSE_PASS_COLOR)
		check(label + ": the last flip showed the other verdict than the landing", last_was_pass != (gained > 0),
				"last flip %s, outcome %s" % ["pass" if last_was_pass else "fail", "pass" if gained > 0 else "fail"])
		check(label + ": no tint left when the card resolves", _tints_at_play == 0
				and _close(_ribbon_at_play, Color.WHITE, 0.02), "%d tint(s), ribbon %s" % [_tints_at_play, str(_ribbon_at_play)])
	else:
		check(label + ": no suspense", not saw_suspense and not seen_pass and not seen_fail)

	Global.surge_amount = 0
	Global.next_roll_modifier = 0
	Global.ink_active = false
	Global.next_guaranteed_roll = -1
	var echo_left := handler._get_status("dice_echo")
	if echo_left != null:
		echo_left.set("triggered_this_turn", true)
	await _wait(1.3)   # the Red spend's 1s read delay
	Global.player.stats.block = 0


# ----------------------------------------------------------------------------- F: sounds

func _section_f() -> void:
	print("\n--- F: click rattle and landing knock ---")
	var all_ok := true
	var detail := ""
	for path in SOUNDS:
		var s := load(path) as AudioStream
		var len_s: float = s.get_length() if s != null else -1.0
		var limit := 0.3 if path.contains("shake") else 0.2
		if s == null or len_s <= 0.0 or len_s > limit:
			all_ok = false
		detail += "%s %.3fs  " % [path.get_file(), len_s]
	check("F1 every new sound loads and is short enough", all_ok, detail)
	var knock: AudioStream = _dice._land_knock_stream()
	check("F2 the landing uses a knock", knock != null and knock.resource_path.begins_with("res://sounds/dice_land_knock_"),
			knock.resource_path if knock != null else "<null>")
	_dice.play_dice_roll_sound()
	var roll_stream: AudioStream = _dice.dice_roll_player.stream
	check("F3 the click uses a short rattle", roll_stream != null
			and roll_stream.resource_path.begins_with("res://sounds/dice_roll_shake_"),
			roll_stream.resource_path if roll_stream != null else "<null>")
	_dice.dice_roll_player.stop()


# ---------------------------------------------------------------------------- G: filters

func _section_g() -> void:
	print("\n--- G: face textures sample their mipmaps ---")
	const MIP := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	check("G1 the big die", _dice.dice_display.texture_filter == MIP)
	check("G1b the next-roll face and the roll history", _dice.next_roll_texture.texture_filter == MIP
			and _dice.roll_history.texture_filter == MIP)
	var slots_ok := true
	for i in range(1, 10):
		var tex: TextureRect = _iface.get("dice_%d_texture" % i)
		if tex == null or tex.texture_filter != MIP:
			slots_ok = false
	check("G2 the nine tray slots", slots_ok)
	var scout := _battle.get_node_or_null("ScoutPanel/HBoxContainer") as CanvasItem
	var children_inherit := true
	if scout != null:
		for c in scout.get_children():
			if c is CanvasItem and (c as CanvasItem).texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
				children_inherit = false
	check("G3 the Scout faces", scout != null and scout.texture_filter == MIP and children_inherit)


# ---------------------------------------------------------------------------------- reel
# DICE_LOOKS_REEL=1 plays the pass as one scripted sequence for Movie Maker (windowed):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_dice_looks.tscn \
#       --write-movie <out>/f.png --fixed-fps 30 --resolution 1280x720 \
#       --rendering-driver opengl3 --position 2000,2000
# Each beat prints its frame number, so the frames and the wav can be cut per beat.

func _mark(label: String) -> void:
	print("[reel] %-34s frame %d  window mode %d" % [label, Engine.get_frames_drawn(),
			DisplayServer.window_get_mode()])


func _reel() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Global.blue_dice_current_amount = 3
	Events.dice_amount_changed.emit()
	_mark("rest: blank face")
	await _wait(1.0)
	_mark("roll 3")
	_roll(3)
	await _wait(1.3)
	_mark("roll 5")
	_roll(5)
	await _wait(1.3)
	_mark("a card spends the Power")
	Events.dice_roll_reset.emit()
	await _wait(1.1)
	_mark("last die: roll 6 (its Power keeps it lit)")
	_roll(6)
	await _wait(1.6)
	_mark("a card spends that Power: the die sleeps")
	Events.dice_roll_reset.emit()
	await _wait(1.3)
	_mark("switch to red")
	Global.red_dice_current_amount = 2
	_click_slot(2)
	await _wait(1.2)
	_mark("socket Aegis")
	await _socket(AEGIS)
	_mark("red roll 4 (passes)")
	Global.tutorial_forced_rolls = [4]
	_dice.roll_dice()
	await _wait(2.4)
	_mark("socket Aegis again")
	await _socket(AEGIS)
	_mark("red roll 6 (fails)")
	Global.roll_value = 0
	Global.roll_history = []
	Global.tutorial_forced_rolls = [6]
	_dice.roll_dice()
	await _wait(2.4)
	_mark("back to blue, Golem kept")
	Global.blue_dice_current_amount = 2
	Global.even_dice_max_amount = maxi(int(Global.even_dice_max_amount), 1)
	Global.even_dice_current_amount = 1
	_iface.initialize_dices()
	_iface._on_dice_amount_changed()
	_click_slot(1)
	await _wait(1.0)
	_mark("end turn: drain")
	_battle.battle_ui._on_end_turn_button_pressed()
	await _wait(2.2)
	_mark("reel end")


# ------------------------------------------------------------------------ H: leftovers

func _section_h() -> void:
	print("\n--- H: nothing left behind ---")
	await _wait(0.6)
	var ghosts := get_tree().get_nodes_in_group("die_face_clear_ghost").size()
	var tweens: Array = _dice._red_suspense_tweens
	var suspense: bool = _dice._red_suspense
	var tints := get_tree().get_nodes_in_group("red_suspense_tint").size()
	var tint_refs: Array = _dice._red_suspense_tints
	check("H1 no face ghost or suspense state survives", ghosts == 0
			and tweens.is_empty() and not suspense and tints == 0 and tint_refs.is_empty(),
			"ghosts %d tweens %d tints %d" % [ghosts, tweens.size(), tints])
