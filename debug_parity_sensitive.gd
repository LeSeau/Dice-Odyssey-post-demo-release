extends Node

# Pins the Parity Brothers' ACTUAL mechanic (Julien, 2026-09-08): they are odd/even
# SENSITIVE - each takes 50% more damage while the player's banked Power has his parity.
# A vulnerability window, never a resistance, and never the Strength-feed that was built by
# mistake first.
#
# Sections
#   A  both brothers carry a DMG_TAKEN modifier value keyed to their id
#   B  the invariant that makes the fight a routing puzzle: at ANY Power, EXACTLY ONE
#      brother is soft - never both, never neither
#   C  real damage through Enemy.take_damage(): odd Power hits the Odd Brother 50% harder
#      than even Power does, and the even Power number is the unmodified baseline
#   D  the mirror, on the Even Brother
#   E  Mech's +/-1 as a parity flipper: Power 7 -> 8 moves the soft target
#   F  NEGATIVE CONTROL - neutralise the modifier and the whole difference must vanish,
#      otherwise section C was measuring something else
#
# Run (headless is fine, nothing here measures text):
#   Godot_v4.3-stable_win64_console.exe --path . --headless res://debug_parity_sensitive.tscn

const FIGHT := "res://battles/tier_elite_brothers.tres"
const PROBE_DAMAGE := 10

var _battle: Node = null
var _hands := 0
var _pass := 0
var _fail := 0


func _ready() -> void:
    Events.player_hand_drawn.connect(func() -> void: _hands += 1)
    await get_tree().process_frame
    await _boot()

    var odd := _brother("odd_sensitive")
    var even := _brother("even_sensitive")
    if odd == null or even == null:
        print("FATAL: brothers not found")
        get_tree().quit(1)
        return

    print("--- A: modifier wiring ---")
    _check("Odd Brother has an odd_sensitive DMG_TAKEN value", _value(odd, "odd_sensitive") != null)
    _check("Even Brother has an even_sensitive DMG_TAKEN value", _value(even, "even_sensitive") != null)

    print("")
    print("--- B: exactly one brother is soft at any Power ---")
    for power in [0, 1, 2, 3, 7, 8, 12, 15]:
        _set_power(power)
        var o: bool = _value(odd, "odd_sensitive").percent_value > 0.0
        var e: bool = _value(even, "even_sensitive").percent_value > 0.0
        _check("Power %d -> exactly one soft (odd=%s even=%s)" % [power, o, e], o != e)

    print("")
    print("--- C: real damage, Odd Brother ---")
    var odd_at_odd := _hit(odd, 7)
    var odd_at_even := _hit(odd, 8)
    print("  Power 7 (odd)  -> %d HP lost" % odd_at_odd)
    print("  Power 8 (even) -> %d HP lost" % odd_at_even)
    _check("odd Power is the baseline +50%% (%d == %d)" % [odd_at_odd, int(PROBE_DAMAGE * 1.5)],
        odd_at_odd == int(PROBE_DAMAGE * 1.5))
    _check("even Power is unmodified (%d == %d)" % [odd_at_even, PROBE_DAMAGE],
        odd_at_even == PROBE_DAMAGE)

    print("")
    print("--- D: the mirror, Even Brother ---")
    var even_at_even := _hit(even, 8)
    var even_at_odd := _hit(even, 7)
    print("  Power 8 (even) -> %d HP lost" % even_at_even)
    print("  Power 7 (odd)  -> %d HP lost" % even_at_odd)
    _check("even Power is the baseline +50%%", even_at_even == int(PROBE_DAMAGE * 1.5))
    _check("odd Power is unmodified", even_at_odd == PROBE_DAMAGE)

    print("")
    print("--- E: Mech +/-1 flips which brother is soft ---")
    _set_power(7)
    var soft_at_7 := "odd" if _value(odd, "odd_sensitive").percent_value > 0.0 else "even"
    _set_power(8)
    var soft_at_8 := "odd" if _value(odd, "odd_sensitive").percent_value > 0.0 else "even"
    print("  Power 7 soft = %s | Power 8 soft = %s" % [soft_at_7, soft_at_8])
    _check("a single +1 moves the soft target", soft_at_7 != soft_at_8)

    print("")
    print("--- F: NEGATIVE CONTROL (modifier neutralised) ---")
    _value(odd, "odd_sensitive").percent_value = 0.0
    var nc_odd := _hit_no_refresh(odd, 7)
    print("  Power 7 with the value forced to 0 -> %d HP lost" % nc_odd)
    _check("difference vanishes, so section C measured THIS modifier",
        nc_odd == PROBE_DAMAGE)

    print("")
    print("=== %d checks, %d FAIL ===" % [_pass + _fail, _fail])
    get_tree().quit(1 if _fail > 0 else 0)


# ---------------------------------------------------------------- helpers

func _boot() -> void:
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
    _battle.act_tier = 3
    relic_handler.add_relic(warrior.starting_relic)
    var before := _hands
    _battle.start_battle()
    var elapsed := 0.0
    while elapsed < 15.0 and _hands <= before:
        await get_tree().process_frame
        elapsed += get_process_delta_time()


func _brother(status_id: String) -> Enemy:
    for e in get_tree().get_nodes_in_group("enemies"):
        var enemy := e as Enemy
        if enemy == null:
            continue
        if _value(enemy, status_id) != null:
            return enemy
    return null


func _value(enemy: Enemy, source: String) -> ModifierValue:
    var m: Modifier = enemy.modifier_handler.get_modifier(Modifier.Type.DMG_TAKEN)
    return m.get_value(source) if m else null


# Sets the banked Power the way the game does and lets the statuses resync.
func _set_power(power: int) -> void:
    Global.roll_value = power
    Events.change_current_power.emit()


func _hit(enemy: Enemy, power: int) -> int:
    _set_power(power)
    return _hit_no_refresh(enemy, power)


func _hit_no_refresh(enemy: Enemy, _power: int) -> int:
    enemy.stats.block = 0
    var before: int = enemy.stats.health
    enemy.take_damage(PROBE_DAMAGE, Modifier.Type.DMG_TAKEN)
    return before - enemy.stats.health


func _check(label: String, cond: bool) -> void:
    if cond:
        _pass += 1
        print("  PASS  " + label)
    else:
        _fail += 1
        print("  FAIL  " + label)
