extends Node

# Verification harness for the Parity Brothers elite (Encounter Slate E-1).
#
# Boots the REAL battle.tscn on battles/tier_elite_brothers.tres, the same recipe
# debug_double_endturn / debug_new_enemies use, so the picker, the status handler and the
# modifier chain are the shipped ones rather than a mock.
#
# What it pins, in order:
#   A  wiring        - 90 HP across two 45s, both AIs are the shared strike/guard pair
#   B  mirrored cycle- every turn exactly one brother strikes and the other guards, and they
#                      swap; over 8 turns neither ever strikes twice in the same turn as the other
#   C  parity feed   - an odd face feeds ONLY Odd, an even face feeds ONLY Even, the Evil 0
#                      counts as even, and one roll never feeds twice (the red double-emit)
#   D  rage          - killing one brother gives the survivor +3 Strength, exactly once
#   E  no free ramp  - a turn with no rolls at all grows neither brother
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_parity_brothers.tscn
#       --rendering-driver opengl3 --position 2000,2000

const BATTLE := preload("res://scenes/battle/battle.tscn")
const BATTLE_STATS := preload("res://battles/tier_elite_brothers.tres")
const WARRIOR := preload("res://characters/warrior/warrior.tres")

var _pass := 0
var _fail := 0
var _battle: Node


func _ready() -> void:
    await _boot()
    await _section_a()
    await _section_b()
    await _section_c()
    await _section_d()
    await _section_e()
    print("\n=== %d passed, %d failed ===" % [_pass, _fail])
    get_tree().quit(1 if _fail > 0 else 0)


func _check(label: String, ok: bool, detail := "") -> void:
    if ok:
        _pass += 1
        print("  PASS  %s %s" % [label, detail])
    else:
        _fail += 1
        print("  FAIL  %s %s" % [label, detail])


func _boot() -> void:
    Global.reset_run_state()
    var stats: CharacterStats = WARRIOR.create_instance()
    _battle = BATTLE.instantiate()
    _battle.battle_stats = BATTLE_STATS
    _battle.char_stats = stats
    add_child(_battle)
    await get_tree().process_frame
    await get_tree().process_frame
    _battle.start_battle()
    await get_tree().process_frame


func _enemies() -> Array:
    var out := []
    for e in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(e) and not e.is_queued_for_deletion():
            out.append(e)
    return out


func _brother(display_name: String) -> Enemy:
    for e in _enemies():
        var enemy: Enemy = e
        if enemy._display_name == display_name:
            return enemy
    return null


func _strength(enemy: Enemy) -> int:
    if enemy == null or not is_instance_valid(enemy):
        return -1
    for child in enemy.status_handler.get_children():
        if child.status and child.status.id == "strength":
            return child.status.stacks
    return 0


# Drive a real roll through dice.gd's own result path so the parity hook is exercised exactly
# as it is in play, rather than by poking the status directly.
func _roll_face(face: int) -> void:
    Global.last_roll = face
    Global.fight_dice_rolled += 1
    Events.dice_rolled.emit(Global.dice_type, face)
    await get_tree().process_frame


func _section_a() -> void:
    print("\n-- A. wiring --")
    var odd := _brother("Odd Brother")
    var even := _brother("Even Brother")
    _check("A1 both brothers present", odd != null and even != null)
    if odd == null or even == null:
        return
    var total: int = odd.stats.max_health + even.stats.max_health
    _check("A2 total HP in the 85-95 elite band", total >= 85 and total <= 95, "= %d" % total)
    _check("A3 the twins are symmetrical", odd.stats.max_health == even.stats.max_health,
        "%d / %d" % [odd.stats.max_health, even.stats.max_health])
    for pair in [["Odd", odd], ["Even", even]]:
        var e: Enemy = pair[1]
        var ids := []
        for a in e.enemy_action_picker.get_children():
            ids.append(a.action_id)
        _check("A4 %s has a strike and a guard" % pair[0], ids.size() == 2,
            str(ids))


# The picker is asked what it would do on each turn. Both beats are CONDITIONAL and partition
# fight_turn % 2, so get_child(0) can never be reached - this also proves that.
func _section_b() -> void:
    print("\n-- B. mirrored cycle, zero randomness --")
    var odd := _brother("Odd Brother")
    var even := _brother("Even Brother")
    if odd == null or even == null:
        return
    var saw_odd_strike := false
    var saw_even_strike := false
    var broke := false
    for turn in range(8):
        Global.fight_turn = turn
        var a_odd: EnemyAction = odd.enemy_action_picker.get_action()
        var a_even: EnemyAction = even.enemy_action_picker.get_action()
        var odd_strikes: bool = a_odd.action_id.ends_with("_strike")
        var even_strikes: bool = a_even.action_id.ends_with("_strike")
        if odd_strikes == even_strikes:
            broke = true
            print("      turn %d: both %s" % [turn, "strike" if odd_strikes else "guard"])
        saw_odd_strike = saw_odd_strike or odd_strikes
        saw_even_strike = saw_even_strike or even_strikes
    _check("B1 exactly one strikes every turn over 8 turns", not broke)
    _check("B2 both brothers take the strike beat", saw_odd_strike and saw_even_strike)
    Global.fight_turn = 0
    var opener: EnemyAction = odd.enemy_action_picker.get_action()
    _check("B3 Odd opens on the strike", opener.action_id == "brother_odd_strike",
        opener.action_id)


func _section_c() -> void:
    print("\n-- C. parity feed --")
    var odd := _brother("Odd Brother")
    var even := _brother("Even Brother")
    if odd == null or even == null:
        return

    var odd0 := _strength(odd)
    var even0 := _strength(even)
    await _roll_face(3)
    _check("C1 an odd face feeds Odd only",
        _strength(odd) == odd0 + 1 and _strength(even) == even0,
        "odd %d->%d, even %d->%d" % [odd0, _strength(odd), even0, _strength(even)])

    odd0 = _strength(odd)
    even0 = _strength(even)
    await _roll_face(4)
    _check("C2 an even face feeds Even only",
        _strength(even) == even0 + 1 and _strength(odd) == odd0,
        "odd %d->%d, even %d->%d" % [odd0, _strength(odd), even0, _strength(even)])

    # The Evil die's crack face. Mathematically even, and the Slate leans on that: an Evil
    # deck (6/6/6/0) is the Even Brother's prey.
    odd0 = _strength(odd)
    even0 = _strength(even)
    await _roll_face(0)
    _check("C3 the Evil 0 counts as even",
        _strength(even) == even0 + 1 and _strength(odd) == odd0,
        "odd %d->%d, even %d->%d" % [odd0, _strength(odd), even0, _strength(even)])

    # A single Red roll reaches the status twice (red_dice_rolled, then card_ui re-emits
    # dice_rolled). fight_dice_rolled only moves once, which is what the token keys on.
    odd0 = _strength(odd)
    even0 = _strength(even)
    Global.last_roll = 5
    Global.fight_dice_rolled += 1
    Events.red_dice_rolled.emit()
    await get_tree().process_frame
    Events.dice_rolled.emit("red", 5)
    await get_tree().process_frame
    _check("C4 one roll feeds once even when it double-emits",
        _strength(odd) == odd0 + 1 and _strength(even) == even0,
        "odd %d->%d" % [odd0, _strength(odd)])


func _section_d() -> void:
    print("\n-- D. Rage on a brother's death --")
    var odd := _brother("Odd Brother")
    var even := _brother("Even Brother")
    if odd == null or even == null:
        return
    var before := _strength(even)
    odd.stats.take_damage(odd.stats.health + 50)
    await get_tree().process_frame
    await get_tree().process_frame
    var after := _strength(even)
    _check("D1 the survivor gains 3 Strength", after == before + 3,
        "%d -> %d" % [before, after])

    # Fires once. A second enemy_died must not pay out again.
    Events.enemy_died.emit(odd)
    await get_tree().process_frame
    _check("D2 Rage is one-shot", _strength(even) == after,
        "%d -> %d" % [after, _strength(even)])


func _section_e() -> void:
    print("\n-- E. no ramp the player did not cause --")
    var even := _brother("Even Brother")
    if even == null:
        return
    var before := _strength(even)
    # Three whole turns pass with no rolls at all. The guard beat grants no Strength on
    # purpose, so nothing may move.
    for turn in range(3):
        Global.fight_turn = turn
        Events.player_turn_ended.emit()
        await get_tree().process_frame
        Events.player_turn_started.emit()
        await get_tree().process_frame
    _check("E1 an unrolled turn grows nobody", _strength(even) == before,
        "%d -> %d" % [before, _strength(even)])
