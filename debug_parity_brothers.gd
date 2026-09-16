extends Node

# Verification harness for the Parity Brothers elite (Encounter Slate E-1).
#
# Boots the REAL battle.tscn on battles/tier_elite_brothers.tres, the same recipe
# debug_double_endturn / debug_new_enemies use, so the picker, the status handler and the
# modifier chain are the shipped ones rather than a mock.
#
# ⚠ Sections C/D/E were REWRITTEN 2026-09-14 and the old ones were wrong twice over. The old
# C measured the parity FEED (odd/even faces granting the brothers Strength), which has been
# orphaned since 09-08 in favour of parity_sensitive - so it had been failing silently ever
# since. The old D measured brothers_rage, which is now cut. The vulnerability window itself
# is pinned by its own harness, debug_parity_sensitive.gd; this file owns the beats.
#
# What it pins, in order:
#   A  wiring        - 90 HP across two 45s, the shared strike/guard pair, block 6, and the
#                      guard's rider icon so the intent cannot silently hide the buff again
#   B  mirrored cycle- every turn exactly one brother strikes and the other guards, and they
#                      swap; over 8 turns they are never on the same beat
#   C  the hand-off  - a guard grants Strength to the OTHER twin and never to itself, in the
#                      exported amount, with a NEGATIVE CONTROL
#   D  no free ramp  - rolling faces grows nobody (the dead feed) and neither do idle turns
#   E  death         - no payout when a brother dies; the survivor drops the guard and
#                      strikes every turn instead
#
# Run (headless is fine, nothing here measures text):
#   Godot_v4.3-stable_win64_console.exe --path . --headless res://debug_parity_brothers.tscn

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
    # ⚠ muscle.tres carries id "strength", NOT "muscle" - a wrong id here returns 0 and turns
    # every assertion below into a silent false failure.
    for child in enemy.status_handler.get_children():
        if child.status and child.status.id == "strength":
            return child.status.stacks
    return 0


func _action(enemy: Enemy, suffix: String) -> EnemyAction:
    if enemy == null or not is_instance_valid(enemy):
        return null
    for a in enemy.enemy_action_picker.get_children():
        var action: EnemyAction = a
        if action.action_id.ends_with(suffix):
            return action
    return null


# Run the real beat rather than poking the status: the picker has already wired enemy/target/
# modifiers on every child, so perform_action() is exactly what the enemy turn would call.
func _perform(action: EnemyAction) -> void:
    action.perform_action()
    await get_tree().process_frame
    await get_tree().process_frame


# Drive a face through dice.gd's own result path, so any roll hook is exercised as it is in
# play rather than by hand.
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
        _check("A4 %s has a strike and a guard" % pair[0], ids.size() == 2, str(ids))

    var guard := _action(odd, "_guard")
    _check("A5 the guard blocks 6", guard != null and guard.block == 6,
        "= %d" % (guard.block if guard else -1))
    # The buff is invisible without a rider glyph, which is the intent-honesty bug this
    # project has already fixed once across the whole roster. Pin it.
    _check("A6 the guard intent carries a rider icon",
        guard != null and guard.intent != null and guard.intent.icon2 != null)
    # No brother may start the fight already carrying Strength - the ramp has to be earned.
    _check("A7 both start at 0 Strength", _strength(odd) == 0 and _strength(even) == 0,
        "odd %d, even %d" % [_strength(odd), _strength(even)])


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


# The fight's whole clock. Read the exported amount instead of hardcoding 2, so retuning the
# dial does not make this harness cry wolf about a change that was deliberate.
func _section_c() -> void:
    print("\n-- C. the guard hands Strength to the other twin --")
    var odd := _brother("Odd Brother")
    var even := _brother("Even Brother")
    if odd == null or even == null:
        return

    var odd_guard := _action(odd, "_guard")
    var even_guard := _action(even, "_guard")
    if odd_guard == null or even_guard == null:
        _check("C0 both guards found", false)
        return
    var amount: int = odd_guard.strength_to_brother

    var odd0 := _strength(odd)
    var even0 := _strength(even)
    await _perform(odd_guard)
    _check("C1 Odd's guard buffs Even, never itself",
        _strength(even) == even0 + amount and _strength(odd) == odd0,
        "odd %d->%d, even %d->%d" % [odd0, _strength(odd), even0, _strength(even)])

    odd0 = _strength(odd)
    even0 = _strength(even)
    await _perform(even_guard)
    _check("C2 Even's guard buffs Odd, never itself",
        _strength(odd) == odd0 + amount and _strength(even) == even0,
        "odd %d->%d, even %d->%d" % [odd0, _strength(odd), even0, _strength(even)])

    # NEGATIVE CONTROL. Zero the rider and the whole movement must vanish - otherwise C1/C2
    # were measuring something else that happens to bump Strength on a guard beat.
    odd0 = _strength(odd)
    even0 = _strength(even)
    odd_guard.strength_to_brother = 0
    await _perform(odd_guard)
    _check("C3 control: a 0 rider moves nothing",
        _strength(odd) == odd0 and _strength(even) == even0,
        "odd %d->%d, even %d->%d" % [odd0, _strength(odd), even0, _strength(even)])
    odd_guard.strength_to_brother = amount

    # The block number the player reads has to be the number that lands; Modifier.Type has no
    # block entry, so the exported value is the whole truth and update_intent_text prints it.
    odd_guard.update_intent_text()
    _check("C4 the guard intent prints its own block value",
        odd_guard.intent.current_text == str(odd_guard.block),
        "'%s' vs %d" % [odd_guard.intent.current_text, odd_guard.block])


func _section_d() -> void:
    print("\n-- D. nothing grows that the brothers did not earn --")
    var odd := _brother("Odd Brother")
    var even := _brother("Even Brother")
    if odd == null or even == null:
        return

    # The orphaned parity FEED regression guard: faces must not buy the brothers anything.
    # Odd, even, and the Evil die's crack face, which is mathematically even.
    var odd0 := _strength(odd)
    var even0 := _strength(even)
    for face in [3, 4, 0, 6, 1]:
        await _roll_face(face)
    _check("D1 rolling faces grows nobody",
        _strength(odd) == odd0 and _strength(even) == even0,
        "odd %d->%d, even %d->%d" % [odd0, _strength(odd), even0, _strength(even)])

    # And turns passing on their own do nothing either: the growth is on the beat, not the
    # clock, so a turn in which neither brother acts must be free.
    odd0 = _strength(odd)
    even0 = _strength(even)
    for turn in range(3):
        Global.fight_turn = turn
        Events.player_turn_ended.emit()
        await get_tree().process_frame
        Events.player_turn_started.emit()
        await get_tree().process_frame
    _check("D2 an idle turn grows nobody",
        _strength(odd) == odd0 and _strength(even) == even0,
        "odd %d->%d, even %d->%d" % [odd0, _strength(odd), even0, _strength(even)])


func _section_e() -> void:
    print("\n-- E. death: no payout, and the survivor's guard goes quiet --")
    var odd := _brother("Odd Brother")
    var even := _brother("Even Brother")
    if odd == null or even == null:
        return
    var even_guard := _action(even, "_guard")

    var before := _strength(even)
    # ⚠ Kill through Enemy.take_damage(), NOT stats.take_damage(): the death path (enemy_died,
    # leaving the group, the death sequence) hangs off a 0.06s flash tween inside the Enemy,
    # so poking the stats resource drops the HP to 0 and fires none of it. The previous
    # version of this section did exactly that, which is why its rage assertion was worthless.
    # Block has to be cleared too - section C left this body guarding.
    odd.take_damage(odd.stats.health + odd.stats.block + 50, Modifier.Type.DMG_TAKEN)
    await get_tree().create_timer(0.3).timeout
    # brothers_rage is cut. A survivor that still gained Strength here would mean the status
    # crept back into the fight scene.
    _check("E1 the survivor gains nothing from the death", _strength(even) == before,
        "%d -> %d" % [before, _strength(even)])
    _check("E2 the corpse left the enemies group", _brother("Odd Brother") == null)

    # The load-bearing half. Ask the REAL picker, turn by turn: with no twin left the survivor
    # must come up strike every single time, never the guard. This is also what keeps the
    # blind get_child(0) fallback out of reach now that the % 2 partition no longer applies.
    var guards := 0
    var strikes := 0
    for turn in range(8):
        Global.fight_turn = turn
        var picked: EnemyAction = even.enemy_action_picker.get_action()
        if picked.action_id.ends_with("_guard"):
            guards += 1
        elif picked.action_id.ends_with("_strike"):
            strikes += 1
    _check("E3 the lone survivor strikes on all 8 turns", strikes == 8 and guards == 0,
        "%d strikes / %d guards" % [strikes, guards])
    _check("E4 its guard refuses itself on both parities",
        even_guard != null and not even_guard.is_performable(),
        "turn %d" % Global.fight_turn)

    # Belt-and-braces: if a future picker change ever ran the guard while alone anyway, it must
    # block and buff nobody rather than falling back to itself or erroring on a freed node.
    before = _strength(even)
    var block_before: int = even.stats.block
    await _perform(even_guard)
    _check("E5 running it anyway buffs nobody and still blocks",
        _strength(even) == before and even.stats.block > block_before,
        "str %d->%d, block %d->%d" % [before, _strength(even), block_before, even.stats.block])
