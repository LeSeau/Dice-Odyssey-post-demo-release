extends Node

# Regression harness for "skipping the tutorial mid-fight must not leave the 35-damage swing
# armed" (Julien, 2026-08-29: the player is not guaranteed to kill or block it).
#
# The tutorial Skeleton pokes for 6 and winds up for 35 on its THIRD attack. That finale only
# makes sense as the payoff to a scripted turn 3; skip the script and it is an unblockable
# one-shot. tutorial_skeleton_action.gd now returns the ordinary damage whenever tutorial_on is
# false, and TutorialDirector._release_tutorial() redraws enemy intents so the number on screen
# stops advertising a hit that can no longer land.
#
# Boots a REAL battle.tscn on the REAL tutorial fight with tutorial_on = true, then presses the
# REAL Skip button (_on_skip_pressed), so the whole release path runs rather than a stand-in.
#
# Section A is the control: BEFORE the skip the intent must read 35. If that ever stops being
# true the later checks would pass vacuously, on a Skeleton that never threatened anything.
# Section D pins the other direction - an unskipped tutorial still gets its finale.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_tutorial_skip_bighit.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tutorial_fight.tres"

var checks := 0
var fails := 0
var hands_drawn := 0
var _battle: Battle
var _skeleton: Node
var _action: Node
var _director: Node


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

    await _scenario_control_big_hit_is_armed()
    await _scenario_skip_disarms_it()
    await _scenario_real_damage_is_six()
    await _scenario_unskipped_tutorial_keeps_its_finale()

    print("\n==== TUTORIAL SKIP / BIG HIT: %d checks, %d fail(s) ====" % [checks, fails])
    print("ALL PASS" if fails == 0 else "FAILURES PRESENT")
    get_tree().quit(1 if fails > 0 else 0)


func _boot_battle() -> void:
    # Must be set BEFORE start_battle: the director, the forced hand and the forced rolls all
    # read it while the fight is being built.
    Global.tutorial_on = true

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
    _battle.act_tier = 0
    relic_handler.add_relic(warrior.starting_relic)

    _battle.start_battle()
    await _await_until(func() -> bool: return hands_drawn > 0, 15.0)

    _skeleton = get_tree().get_nodes_in_group("enemies")[0]
    _action = _skeleton.current_action
    _director = _battle.get_node("TutorialDirector")


# The intent label is base_text ("%s") filled with the resolved damage, so it is just a number.
func _intent_text() -> String:
    return str(_action.intent.current_text)


# Puts the Skeleton one attack away from its finale without running two real enemy turns.
func _arm_third_attack() -> void:
    _action._attacks_landed = _action.big_hit_after_attacks
    _skeleton.update_intent()


func _scenario_control_big_hit_is_armed() -> void:
    print("\n--- A (control): with the tutorial running, the third attack really is 35 ---")
    _arm_third_attack()
    check("intent shows the big hit before any skip", _intent_text() == "35", _intent_text())
    check("tutorial is still running", Global.tutorial_on, "")


func _scenario_skip_disarms_it() -> void:
    print("\n--- B: pressing Skip disarms it AND redraws the intent ---")
    _director._on_skip_pressed()
    await get_tree().process_frame
    check("Skip cleared tutorial_on", not Global.tutorial_on, "")
    # Deliberately NOT calling update_intent() here - _release_tutorial has to have done it,
    # otherwise the player stares at a 35 that can no longer happen.
    check("intent redrawn to the ordinary poke", _intent_text() == "6", _intent_text())


func _scenario_real_damage_is_six() -> void:
    print("\n--- C: end to end, the swing actually lands for 6 ---")
    var player = _action.target
    check("player handle resolved", player != null, "")
    if player == null:
        return
    player.stats.block = 0
    var before: int = player.stats.health
    _skeleton.do_turn()
    await _await_until(func() -> bool: return player.stats.health != before, 6.0)
    var dealt: int = before - player.stats.health
    check("third attack after a skip deals 6, not 35", dealt == 6, "dealt %d" % dealt)
    check("player survived", player.stats.health > 0, "hp %d" % player.stats.health)


func _scenario_unskipped_tutorial_keeps_its_finale() -> void:
    print("\n--- D: an UNskipped tutorial still gets its finale ---")
    Global.tutorial_on = true
    _arm_third_attack()
    check("finale intact while the script runs", _intent_text() == "35", _intent_text())
    Global.tutorial_on = false
    _skeleton.update_intent()
    check("and drops again the moment the flag clears", _intent_text() == "6", _intent_text())


func _await_until(predicate: Callable, timeout: float) -> void:
    var elapsed := 0.0
    while elapsed < timeout:
        if predicate.call():
            return
        await get_tree().process_frame
        elapsed += get_process_delta_time()
    push_error("timed out waiting for condition")
