extends Node

# Regression harness for the two fixes from the 2026-09-25 card pool review (H-183):
#
#   A. Crescendo / Parasite: power_generated_this_turn is credited with the Power a roll
#      ACTUALLY added (face + Boost + Surge - Weak), not the raw face. Before the fix a Surge 2
#      roll of 4 counted 4, a Boost 5 roll of 3 counted 3 and a Weak 2 roll of 4 counted 4.
#   B. A second copy of Die Hard, Dice Echo, Buzzer Shot, Marionette, Anarchy, Artillery,
#      Effigy or Rupture is merged into the first (Status.absorb_copy) instead of dropped.
#
# NEGATIVE CONTROL (B0): a plain NONE status that does not override absorb_copy is still
# dropped on its second copy, so every B pass is driven by the opt-in and not by a blanket
# change to StatusHandler.
#
# Boots a REAL battle.tscn through start_battle() (same recipe as debug_parasite_power.gd)
# and drives Global.testing_mode forced rolls, so the real dice code path runs.
#
# Run (headless is enough, nothing here measures pixels or text):
#   Godot_v4.3-stable_win64_console.exe --headless --path . res://debug_copies_and_power.tscn

const FIGHT := "res://battles/tier_1_crab_satyr.tres"

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _dice: Node
var _player: Node
var _victim: Node


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

    await _boot_battle()

    await _section_a_power_counter()
    await _section_b0_negative_control()
    await _section_b1_die_hard()
    await _section_b2_buzzer_shot()
    await _section_b3_dice_echo()
    await _section_b4_effigy_and_rupture()
    await _section_b5_start_of_turn_statuses()
    _section_b6_single_copy_text()

    print("\n==== COPIES + POWER COUNTER: %d checks, %d fail(s) ====" % [checks, fails])
    print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
    get_tree().quit(1 if fails > 0 else 0)


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
    _battle.battle_stats = load(FIGHT)
    _battle.act_tier = 1
    relic_handler.add_relic(warrior.starting_relic)

    _battle.start_battle()
    await _await_until(func() -> bool: return hands_drawn > 0, 15.0)

    _dice = _battle.get_node("ActiveDice")
    _player = _battle.player
    Global.testing_mode = true
    Global.blue_dice_max_amount = 9
    Global.blue_dice_current_amount = 9

    var enemies := get_tree().get_nodes_in_group("enemies")
    _victim = enemies[0]
    # Big HP so Effigy/Rupture/Artillery hits never end the fight mid-harness.
    _victim.stats.max_health = 999
    _victim.stats.health = 999


# Fresh player turn with an empty bank: dice.gd zeroes power_generated_this_turn on
# player_turn_started, and the reset empties roll_value and roll_history.
func _new_turn() -> void:
    Events.player_turn_started.emit()
    await get_tree().process_frame
    Events.dice_roll_reset.emit()
    await get_tree().process_frame


func _roll(face: int) -> void:
    Global.dice_type = "blue"
    Global.blue_dice_current_amount = 9
    Global.tutorial_forced_rolls = [face]
    _dice.roll_dice()
    await get_tree().process_frame


func _dup(path: String) -> Status:
    return (load(path) as Status).duplicate()


func _count_with_id(handler: StatusHandler, id: String) -> int:
    var n := 0
    for s: Status in handler._get_all_statuses():
        if s.id == id:
            n += 1
    return n


# ---------------------------------------------------------------------------------------------
func _section_a_power_counter() -> void:
    print("\n--- A: the turn's Power total counts what the roll actually added ---")

    await _new_turn()
    await _roll(4)
    check("A1 plain roll of 4 counts 4", Global.power_generated_this_turn == 4,
            "got %d" % Global.power_generated_this_turn)

    await _new_turn()
    Global.surge_amount = 2
    await _roll(4)
    Global.surge_amount = 0
    check("A2 Surge 2 roll of 4 banks 6 and counts 6",
            Global.roll_value == 6 and Global.power_generated_this_turn == 6,
            "bank %d, counted %d" % [Global.roll_value, Global.power_generated_this_turn])

    await _new_turn()
    Global.next_roll_modifier = 5
    await _roll(3)
    check("A3 Boost 5 roll of 3 banks 8 and counts 8",
            Global.roll_value == 8 and Global.power_generated_this_turn == 8,
            "bank %d, counted %d" % [Global.roll_value, Global.power_generated_this_turn])

    await _new_turn()
    Global.next_roll_modifier = -2
    await _roll(4)
    check("A4 Weak 2 roll of 4 banks 2 and counts 2",
            Global.roll_value == 2 and Global.power_generated_this_turn == 2,
            "bank %d, counted %d" % [Global.roll_value, Global.power_generated_this_turn])

    await _new_turn()
    await _roll(3)
    Global.next_roll_modifier = -6
    await _roll(1)
    check("A5 a roll Weak drags below 0 adds nothing and never subtracts",
            Global.power_generated_this_turn == 3,
            "bank %d, counted %d" % [Global.roll_value, Global.power_generated_this_turn])

    # A card's Power still goes through the other credit path (change_current_power), once.
    await _new_turn()
    await _roll(5)
    Global.roll_value += 4
    Events.change_current_power.emit()
    check("A6 roll 5 + card 4 still counts 9 (no double count)",
            Global.power_generated_this_turn == 9,
            "got %d" % Global.power_generated_this_turn)


# ---------------------------------------------------------------------------------------------
func _section_b0_negative_control() -> void:
    print("\n--- B0 (negative control): a status that does not opt in is still unique ---")
    var handler: StatusHandler = _player.status_handler
    for _i in 2:
        var plain := Status.new()
        plain.id = "harness_plain_unique"
        plain.stack_type = Status.StackType.NONE
        plain.can_expire = false
        plain.stacks = 1
        handler.add_status(plain)
    check("B0 second copy of a plain NONE status is dropped",
            _count_with_id(handler, "harness_plain_unique") == 1
                    and handler._get_status("harness_plain_unique").stacks == 1,
            "stacks %d" % handler._get_status("harness_plain_unique").stacks)


func _section_b1_die_hard() -> void:
    print("\n--- B1: two Die Hards give 2 Block per roll ---")
    var handler: StatusHandler = _player.status_handler
    handler.add_status(_dup("res://statuses/status_hardened_grip.tres"))
    handler.add_status(_dup("res://statuses/status_hardened_grip.tres"))
    var s: Status = handler._get_status("die_hard")
    check("B1 one badge, 2 copies", _count_with_id(handler, "die_hard") == 1 and s.stacks == 2,
            "stacks %d" % s.stacks)
    check("B1 tooltip says 2 Block", s.get_tooltip() == "Gain 2 Block every time you roll a Dice",
            s.get_tooltip())
    await _new_turn()
    var before: int = _player.stats.block
    await _roll(2)
    check("B1 one roll grants 2 Block", _player.stats.block - before == 2,
            "block %d -> %d" % [before, _player.stats.block])


func _section_b2_buzzer_shot() -> void:
    print("\n--- B2: two Buzzer Shots before it fires make the first roll count 5 times ---")
    var handler: StatusHandler = _player.status_handler
    handler.add_status(_dup("res://statuses/status_coiled_spring.tres"))
    handler.add_status(_dup("res://statuses/status_coiled_spring.tres"))
    var s: Status = handler._get_status("buzzer_shot")
    check("B2 one badge, 2 copies", _count_with_id(handler, "buzzer_shot") == 1 and s.stacks == 2,
            "stacks %d" % s.stacks)
    check("B2 tooltip says 5 times", s.get_tooltip().contains("counts 5 times"), s.get_tooltip())
    await _new_turn()  # arms the spring
    await _roll(3)
    check("B2 armed first roll of 3 banks 3 + 3*2*2 = 15", Global.roll_value == 15,
            "bank %d" % Global.roll_value)


func _section_b3_dice_echo() -> void:
    print("\n--- B3: two Dice Echoes make the first roll count triple ---")
    var handler: StatusHandler = _player.status_handler
    handler.add_status(_dup("res://statuses/status_opening_gambit.tres"))
    handler.add_status(_dup("res://statuses/status_opening_gambit.tres"))
    var s: Status = handler._get_status("dice_echo")
    check("B3 one badge, 2 copies", _count_with_id(handler, "dice_echo") == 1 and s.stacks == 2,
            "stacks %d" % s.stacks)
    check("B3 tooltip says triple", s.get_tooltip().contains("counts triple"), s.get_tooltip())
    await _new_turn()
    await _roll(4)
    check("B3 first roll of 4 banks 12", Global.roll_value == 12, "bank %d" % Global.roll_value)
    check("B3 and the turn total counts all 12", Global.power_generated_this_turn == 12,
            "counted %d" % Global.power_generated_this_turn)
    await _roll(2)
    check("B3 second roll is not echoed (12 + 2 = 14)", Global.roll_value == 14,
            "bank %d" % Global.roll_value)


func _section_b4_effigy_and_rupture() -> void:
    print("\n--- B4: two Effigies / two Ruptures on one enemy add their damage ---")
    var handler: StatusHandler = _victim.status_handler
    handler.add_status(_dup("res://statuses/effigy.tres"))
    handler.add_status(_dup("res://statuses/effigy.tres"))
    var eff: Status = handler._get_status("effigy")
    check("B4 Effigy x2 = 10 per six", _count_with_id(handler, "effigy") == 1 and eff.stacks == 10,
            "stacks %d" % eff.stacks)
    check("B4 Effigy tooltip says 10",
            eff.get_tooltip() == "Takes 10 damage every time you roll a 6 this combat", eff.get_tooltip())
    await _new_turn()
    _victim.stats.block = 0
    var hp: int = _victim.stats.health
    await _roll(6)
    await get_tree().process_frame
    check("B4 a rolled 6 hits the cursed enemy for 10", hp - _victim.stats.health == 10,
            "hp %d -> %d" % [hp, _victim.stats.health])

    await _new_turn()
    handler.add_status(_dup("res://statuses/ruptured.tres"))
    handler.add_status(_dup("res://statuses/ruptured.tres"))
    var rup: Status = handler._get_status("ruptured")
    check("B4 Rupture x2 same turn = 6 per roll",
            _count_with_id(handler, "ruptured") == 1 and rup.stacks == 6, "stacks %d" % rup.stacks)
    _victim.stats.block = 0
    hp = _victim.stats.health
    await _roll(2)
    await get_tree().process_frame
    check("B4 one roll of 2 bleeds the enemy for 6", hp - _victim.stats.health == 6,
            "hp %d -> %d" % [hp, _victim.stats.health])


func _section_b5_start_of_turn_statuses() -> void:
    print("\n--- B5: Anarchy / Marionette / Artillery pay once per copy ---")
    var handler: StatusHandler = _player.status_handler

    handler.add_status(_dup("res://statuses/status_dicelord_gift.tres"))
    handler.add_status(_dup("res://statuses/status_dicelord_gift.tres"))
    var gift: Status = handler._get_status("anarchy")
    check("B5 Anarchy x2 = 2 dice per turn", gift.stacks == 2, "stacks %d" % gift.stacks)
    var charged := [0]
    var on_charged := func(_t: String, n: int) -> void: charged[0] += n
    Events.dice_charged.connect(on_charged)
    gift.apply_status(_player)
    Events.dice_charged.disconnect(on_charged)
    check("B5 Anarchy x2 charges 2 dice", charged[0] == 2, "charged %d" % charged[0])

    handler.add_status(_dup("res://statuses/status_marionette.tres"))
    handler.add_status(_dup("res://statuses/status_marionette.tres"))
    var mario: Status = handler._get_status("marionette")
    var cards := [0]
    var on_card := func(_c: Card) -> void: cards[0] += 1
    Events.add_card_to_hand_requested.connect(on_card)
    mario.apply_status(_player)
    Events.add_card_to_hand_requested.disconnect(on_card)
    check("B5 Marionette x2 hands out 2 Scout cards", cards[0] == 2, "cards %d" % cards[0])
    check("B5 Marionette tooltip says 2", mario.get_tooltip().contains("gain 2 Scout 3 cards"),
            mario.get_tooltip())

    handler.add_status(_dup("res://statuses/artillery.tres"))
    handler.add_status(_dup("res://statuses/artillery.tres"))
    var art: Status = handler._get_status("artillery")
    var thrown := [0]
    var on_thrown := func(throws: Array, _origin: Vector2) -> void: thrown[0] += throws.size()
    Events.dice_thrown.connect(on_thrown)
    art.apply_status(_player)
    Events.dice_thrown.disconnect(on_thrown)
    check("B5 Artillery x2 throws 2 dice", thrown[0] == 2, "thrown %d" % thrown[0])


func _section_b6_single_copy_text() -> void:
    print("\n--- B6: a single copy reads exactly like its .tres tooltip ---")
    for path in ["res://statuses/status_hardened_grip.tres", "res://statuses/status_opening_gambit.tres",
            "res://statuses/status_coiled_spring.tres", "res://statuses/artillery.tres",
            "res://statuses/status_marionette.tres", "res://statuses/status_marionette_plus.tres",
            "res://statuses/status_dicelord_gift.tres", "res://statuses/status_dicelord_gift_plus.tres",
            "res://statuses/effigy.tres",
            "res://statuses/effigy_plus.tres", "res://statuses/ruptured.tres",
            "res://statuses/ruptured_plus.tres"]:
        var s: Status = _dup(path)
        check("B6 %s" % path.get_file(), s.get_tooltip() == s.tooltip,
                "'%s' vs '%s'" % [s.get_tooltip(), s.tooltip])


func _await_until(predicate: Callable, timeout: float) -> void:
    var elapsed := 0.0
    while elapsed < timeout:
        if predicate.call():
            return
        await get_tree().process_frame
        elapsed += get_process_delta_time()
    push_error("timed out waiting for condition")
