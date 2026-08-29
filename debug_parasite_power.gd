extends Node

# Regression harness for "Parasite must count ALL Power generated, not just rolls"
# (Julien, 2026-08-29: "parasite does not check for reinforce, only rolls").
#
# Two halves are being pinned:
#   1. dice.gd credits Global.power_generated_this_turn for power gained WITHOUT rolling
#      (Reinforce, Blaze, mech +1, a relic paying out) - and never double counts a roll,
#      which _apply_roll_result already credits itself.
#   2. ParasiteStatus reacts to that, not only to Events.dice_rolled.
#
# Crescendo reads the same global ("Deal damage equal to all Power generated this turn"), so
# section D pins its number too - the fix changes that card as well, and it should.
#
# NEGATIVE CONTROL in section A2: raising Power WITHOUT emitting change_current_power leaves
# the counter alone and Parasite quiet, proving the passes above are actually driven by the
# new path rather than by something that was true all along.
#
# Boots a REAL battle.tscn through start_battle() (same recipe as debug_golem_carryover.gd)
# and drives Global.testing_mode rolls, so the real dice code path runs.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_parasite_power.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
const PARASITE := preload("res://statuses/parasite.tres")

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _dice: Node
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
    _attach_parasite()

    await _scenario_card_power()
    await _scenario_roll_not_double_counted()
    await _scenario_reset_does_not_subtract()
    await _scenario_crescendo_sees_card_power()

    print("\n==== PARASITE / POWER ACCOUNTING: %d checks, %d fail(s) ====" % [checks, fails])
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
    Global.testing_mode = true
    Global.blue_dice_max_amount = 9
    Global.blue_dice_current_amount = 9


# Parasite is Oculus's starting status; the crab/satyr fight is used for its short boot, so
# the status is attached by hand to whichever enemy is alive. Same resource the enemy gets.
func _attach_parasite() -> void:
    var enemies := get_tree().get_nodes_in_group("enemies")
    _victim = enemies[0]
    var parasite: Status = PARASITE.duplicate()
    _victim.status_handler.add_status(parasite)


# NB: the Muscle/Strength status resource has id "strength", not "muscle" - looking up
# "muscle" silently returns 0 and turns every Parasite assertion into a false failure.
func _muscle_stacks() -> int:
    if not _victim.status_handler._has_status("strength"):
        return 0
    return _victim.status_handler._get_status("strength").stacks


# Fresh player turn: dice.gd zeroes power_generated_this_turn AND syncs its shown-power
# baseline, and Parasite rearms its once-per-turn flag.
func _new_turn() -> void:
    Events.player_turn_started.emit()
    await get_tree().process_frame


# What Reinforce/Blaze do: raise the banked number, then announce it.
func _gain_power_like_a_card(amount: int) -> void:
    Global.roll_value += amount
    Events.change_current_power.emit()


func _scenario_card_power() -> void:
    print("\n--- A: Power from a card counts, and arms Parasite ---")
    await _new_turn()
    var before := _muscle_stacks()

    _gain_power_like_a_card(16)
    check("card power credits power_generated_this_turn",
            Global.power_generated_this_turn == 16,
            "got %d" % Global.power_generated_this_turn)
    check("Parasite fires above threshold %d with zero rolls" % ParasiteStatus.PARASITE_THRESHOLD,
            _muscle_stacks() == before + ParasiteStatus.PARASITE_STRENGTH,
            "muscle %d -> %d" % [before, _muscle_stacks()])

    # Once per turn only - a second card must not pay out again.
    var armed := _muscle_stacks()
    _gain_power_like_a_card(20)
    check("Parasite pays out once per turn", _muscle_stacks() == armed,
            "muscle %d" % _muscle_stacks())

    # A refresh-only emit (the ~19 cards that announce without changing the number) is not
    # power generation.
    var total: int = Global.power_generated_this_turn
    Events.change_current_power.emit()
    check("refresh-only emit credits nothing",
            Global.power_generated_this_turn == total,
            "%d -> %d" % [total, Global.power_generated_this_turn])

    print("--- A2 (negative control): silent Power raise must NOT count ---")
    await _new_turn()
    var quiet_before := _muscle_stacks()
    Global.roll_value += 40  # no change_current_power emit
    check("silent raise leaves the counter at 0",
            Global.power_generated_this_turn == 0,
            "got %d" % Global.power_generated_this_turn)
    check("silent raise leaves Parasite quiet", _muscle_stacks() == quiet_before,
            "muscle %d" % _muscle_stacks())


func _scenario_roll_not_double_counted() -> void:
    print("\n--- B: a real roll is credited exactly once ---")
    await _new_turn()
    Global.dice_type = "blue"
    Global.blue_dice_current_amount = 9
    Global.tutorial_forced_rolls = [4]
    _dice.roll_dice()
    await get_tree().process_frame
    check("one forced roll of 4 credits 4, not 8",
            Global.power_generated_this_turn == 4,
            "got %d" % Global.power_generated_this_turn)

    # And a card played after the roll adds on top instead of re-crediting the roll.
    _gain_power_like_a_card(3)
    check("card after a roll adds only its own 3",
            Global.power_generated_this_turn == 7,
            "got %d" % Global.power_generated_this_turn)

    Global.tutorial_forced_rolls = [6]
    _dice.roll_dice()
    await get_tree().process_frame
    check("second roll of 6 brings the total to 13",
            Global.power_generated_this_turn == 13,
            "got %d" % Global.power_generated_this_turn)


func _scenario_reset_does_not_subtract() -> void:
    print("\n--- C: resets and type switches never go negative ---")
    await _new_turn()
    _gain_power_like_a_card(12)
    var banked: int = Global.power_generated_this_turn

    Events.dice_roll_reset.emit()
    await get_tree().process_frame
    check("playing a card (reset) keeps the turn total",
            Global.power_generated_this_turn == banked,
            "%d -> %d" % [banked, Global.power_generated_this_turn])

    _dice._on_active_dice_changed("red")
    await get_tree().process_frame
    check("dice-type switch keeps the turn total",
            Global.power_generated_this_turn == banked,
            "%d -> %d" % [banked, Global.power_generated_this_turn])
    _dice._on_active_dice_changed("blue")
    await get_tree().process_frame


func _scenario_crescendo_sees_card_power() -> void:
    print("\n--- D: Crescendo reads the same total (it says 'all Power generated') ---")
    await _new_turn()
    Global.dice_type = "blue"
    Global.blue_dice_current_amount = 9
    Global.tutorial_forced_rolls = [5]
    _dice.roll_dice()
    await get_tree().process_frame
    _gain_power_like_a_card(4)
    check("roll 5 + card 4 = 9 for Crescendo",
            Global.power_generated_this_turn == 9,
            "got %d" % Global.power_generated_this_turn)


func _await_until(predicate: Callable, timeout: float) -> void:
    var elapsed := 0.0
    while elapsed < timeout:
        if predicate.call():
            return
        await get_tree().process_frame
        elapsed += get_process_delta_time()
    push_error("timed out waiting for condition")
