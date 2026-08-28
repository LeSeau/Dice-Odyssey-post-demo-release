extends Node

# Verification harness for the STS2 card-rarity port (2026-08-28). Not committed.
#   "C:/Users/julie/Desktop/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe" \
#       --path . --headless res://debug_rarity_odds.tscn > rarity_out.txt 2>&1
#
# Boots a real scene instead of --script so the autoloads exist and every touched script is
# actually COMPILED. gdtoolkit only parses syntax; it cannot see a bad type inference, which
# is the failure mode that has silently killed whole files in this project before.
#
# Section D is the negative control: the identical measurement re-run with pity advanced once
# per SCREEN (the old model), which must show elite 2-rare screens jumping back to ~12%. A
# test that cannot fail proves nothing.

const RUNS := 20000
const UPGRADE_SAMPLES := 20000

var _fails := 0
var _new_model := {}
# Modelled walked path per act: 7 normal fights, 1 elite, 1 boss = 18 reward screens per run.
# Built at runtime rather than as a const so this file has no parse-time dependency on
# another class resolving first.
var _screens_per_act: Array = []


func _ready() -> void:
    _screens_per_act = [
        CardRarityDraw.Source.NORMAL, CardRarityDraw.Source.NORMAL, CardRarityDraw.Source.NORMAL,
        CardRarityDraw.Source.NORMAL, CardRarityDraw.Source.NORMAL, CardRarityDraw.Source.NORMAL,
        CardRarityDraw.Source.ELITE, CardRarityDraw.Source.NORMAL, CardRarityDraw.Source.BOSS,
    ]
    print("=== STS2 card-rarity port verification ===")
    # Runs first on purpose - see the note on _section_f_scenes().
    _section_f_scenes()
    _section_a_compile_and_parity()
    _section_b_distribution()
    _section_c_upgrade_roll()
    _section_d_negative_control()
    _section_e_shop()
    print("")
    print("=== %s ===" % ("ALL PASS" if _fails == 0 else "%d FAIL" % _fails))
    get_tree().quit()


func _check(label: String, ok: bool, detail: String = "") -> void:
    if not ok:
        _fails += 1
    var suffix := "" if detail == "" else "  -> " + detail
    print("  [%s] %s%s" % ["PASS" if ok else "FAIL", label, suffix])


func _near(a: float, b: float, tol: float) -> bool:
    return absf(a - b) <= tol


func _pct(part: int, whole: int) -> float:
    if whole == 0:
        return 0.0
    return 100.0 * float(part) / float(whole)


# A. Every touched script compiles, and the constants match the decompiled reference exactly.
func _section_a_compile_and_parity() -> void:
    print("")
    print("A. compile + reference parity")
    for path in [
        "res://custom_resources/card_rarity_draw.gd",
        "res://custom_resources/run_stats.gd",
        "res://scenes/battle_reward/battle_reward.gd",
        "res://scenes/shop/card_shop.gd",
        "res://scenes/run/run.gd",
    ]:
        _check("compiles: %s" % path.get_file(), load(path) != null)

    # Transcribed from sts2_ref/pck/src/Core/Odds/CardRarityOdds.cs (ascension 0) and
    # Core/Factories/CardFactory.cs. If a retune ever drifts these, it shows up here.
    var unc := CardRarityDraw.BASE_UNCOMMON_ODDS
    var rare := CardRarityDraw.BASE_RARE_ODDS
    _check("normal 0.37 / 0.03", unc[CardRarityDraw.Source.NORMAL] == 0.37 \
        and rare[CardRarityDraw.Source.NORMAL] == 0.03)
    _check("elite 0.40 / 0.10", unc[CardRarityDraw.Source.ELITE] == 0.40 \
        and rare[CardRarityDraw.Source.ELITE] == 0.10)
    _check("boss rare 1.0", rare[CardRarityDraw.Source.BOSS] == 1.0)
    _check("shop 0.37 / 0.09", unc[CardRarityDraw.Source.SHOP] == 0.37 \
        and rare[CardRarityDraw.Source.SHOP] == 0.09)
    _check("offset floor/growth/cap = -0.05 / 0.01 / 0.40", RunStats.RARE_OFFSET_FLOOR == -0.05 \
        and RunStats.RARE_OFFSET_GROWTH == 0.01 and RunStats.RARE_OFFSET_CAP == 0.4)
    _check("a Rare resets the offset to the floor",
        CardRarityDraw.advance_offset(0.3, Card.RarityTier.RARE) == RunStats.RARE_OFFSET_FLOOR)
    _check("a non-Rare creeps the offset up",
        _near(CardRarityDraw.advance_offset(0.0, Card.RarityTier.COMMON), 0.01, 0.0001))
    _check("the offset clamps at the cap",
        _near(CardRarityDraw.advance_offset(0.4, Card.RarityTier.COMMON), 0.4, 0.0001))
    _check("boss ignores the offset it is handed",
        CardRarityDraw.roll_rarity(CardRarityDraw.Source.BOSS, RunStats.RARE_OFFSET_FLOOR) \
            == Card.RarityTier.RARE)

    # Run start is under water: 0.03 + (-0.05) < 0, so no Rare is reachable at all. This is
    # what replaced the old bespoke "no jackpot on floor 1" special case.
    var reachable := false
    for _i in 5000:
        if CardRarityDraw.roll_rarity(CardRarityDraw.Source.NORMAL, RunStats.RARE_OFFSET_FLOOR) \
                == Card.RarityTier.RARE:
            reachable = true
    _check("no Rare is possible at the run-start offset", not reachable)


# One run of reward screens. per_screen_pity = the OLD model, used by the negative control.
func _simulate(per_screen_pity: bool) -> Dictionary:
    var tally := {Card.RarityTier.COMMON: 0, Card.RarityTier.UNCOMMON: 0, Card.RarityTier.RARE: 0}
    var multi := {}
    for _run in RUNS:
        var offset := RunStats.RARE_OFFSET_FLOOR
        for _act in 2:
            for source in _screens_per_act:
                var screen_offset := offset
                var rares := 0
                for _slot in 3:
                    var used := screen_offset if per_screen_pity else offset
                    var tier := CardRarityDraw.roll_rarity(source, used)
                    tally[tier] += 1
                    if tier == Card.RarityTier.RARE:
                        rares += 1
                    if not per_screen_pity:
                        offset = CardRarityDraw.advance_offset(offset, tier)
                if per_screen_pity:
                    var screen_result := Card.RarityTier.RARE if rares > 0 else Card.RarityTier.COMMON
                    offset = CardRarityDraw.advance_offset(offset, screen_result)
                if not multi.has(source):
                    multi[source] = [0, 0, 0, 0]
                multi[source][rares] += 1
    return {"tally": tally, "multi": multi}


func _report(res: Dictionary) -> Dictionary:
    var tally: Dictionary = res["tally"]
    var commons: int = tally[Card.RarityTier.COMMON]
    var uncommons: int = tally[Card.RarityTier.UNCOMMON]
    var rares: int = tally[Card.RarityTier.RARE]
    var total := commons + uncommons + rares
    var out := {}
    out["rare_share"] = _pct(rares, total)
    out["rares_per_run"] = float(rares) / float(RUNS)
    print("     per-slot  C %.1f%%  U %.1f%%  R %.1f%%   (%.2f rare offers per run)" % [
        _pct(commons, total), _pct(uncommons, total), out["rare_share"], out["rares_per_run"]])
    var names := ["NORMAL", "ELITE", "BOSS", "SHOP"]
    var multi: Dictionary = res["multi"]
    for source in multi:
        var d: Array = multi[source]
        var n: int = d[0] + d[1] + d[2] + d[3]
        var label: String = names[source]
        var row := [_pct(d[0], n), _pct(d[1], n), _pct(d[2], n), _pct(d[3], n)]
        print("     %-6s screens: 0R %.1f%% | 1R %.1f%% | 2R %.1f%% | 3R %.1f%%" % [
            label, row[0], row[1], row[2], row[3]])
        out[label] = row
    return out


func _section_b_distribution() -> void:
    print("")
    print("B. shipped model - %d runs x 18 reward screens" % RUNS)
    _new_model = _report(_simulate(false))
    var normal: Array = _new_model["NORMAL"]
    var elite: Array = _new_model["ELITE"]
    var boss: Array = _new_model["BOSS"]
    var non_boss: float = float(_new_model["rares_per_run"]) - 6.0
    _check("boss screens are always 3/3 Rare", boss[3] == 100.0)
    _check("normal screens effectively never show 2+ Rares", normal[2] < 0.2 and normal[3] < 0.05,
        "2R %.2f%% / 3R %.2f%%" % [normal[2], normal[3]])
    _check("elite 2-Rare screens stay under 4%", elite[2] < 4.0, "%.2f%%" % elite[2])
    _check("elite never shows 3 Rares", elite[3] < 0.05, "%.2f%%" % elite[3])
    # 14 normal + 2 elite screens = 48 non-boss slots; the 2 boss screens contribute exactly 6.
    _check("non-boss rares per run land in the 2-4 band", non_boss > 2.0 and non_boss < 4.0,
        "%.2f" % non_boss)


func _section_c_upgrade_roll() -> void:
    print("")
    print("C. upgrade roll (CardFactory.RollForUpgrade port)")
    # .new() rather than instantiating the scene: _resolve_reward_card touches none of the
    # @onready nodes, and staying out of the tree means _ready never runs and cannot error.
    var reward = load("res://scenes/battle_reward/battle_reward.gd").new()
    var pool := load("res://characters/warrior/warrior_draftable_cards.tres")
    var commons: Array[Card] = []
    var rares: Array[Card] = []
    for c: Card in pool.cards:
        if c.rarity_tier == Card.RarityTier.RARE:
            rares.append(c)
        elif c.rarity_tier == Card.RarityTier.COMMON and c.can_be_upgraded():
            commons.append(c)
    _check("pool exposes upgradable commons and rares",
        not commons.is_empty() and not rares.is_empty(),
        "%d commons / %d rares" % [commons.size(), rares.size()])

    Global.force_upgraded_card_rewards = false
    for act in [1, 2]:
        Global.current_act = act
        var expected := float(act - 1) * 25.0
        var upgraded := 0
        for i in UPGRADE_SAMPLES:
            var offered: Card = reward._resolve_reward_card(commons[i % commons.size()])
            if offered.upgraded:
                upgraded += 1
        var got := _pct(upgraded, UPGRADE_SAMPLES)
        _check("act %d: commons upgrade at ~%.0f%%" % [act, expected], _near(got, expected, 1.5),
            "%.2f%%" % got)

    Global.current_act = 2
    var rare_upgraded := 0
    for i in UPGRADE_SAMPLES:
        var offered: Card = reward._resolve_reward_card(rares[i % rares.size()])
        if offered.upgraded:
            rare_upgraded += 1
    _check("Rares are never pre-upgraded, even in act 2", rare_upgraded == 0, "%d" % rare_upgraded)

    # Wandering Merchant keeps its unconditional override, Rares and act 1 included.
    Global.force_upgraded_card_rewards = true
    Global.current_act = 1
    var forced: Card = reward._resolve_reward_card(rares[0])
    _check("force_upgraded_card_rewards still overrides act 1 + Rare", forced.upgraded)

    Global.force_upgraded_card_rewards = false
    Global.current_act = 1
    reward.free()


# Faithful copy of the PRE-CHANGE algorithm (git HEAD before 2026-08-28), kept here purely
# as the negative control. Multiplicative weights, elite multipliers applied on top of the
# pity-inflated rare weight, and pity advanced once per SCREEN. Do not "fix" this - it is
# supposed to be the old behaviour.
const LEGACY_COMMON := 6.0
const LEGACY_UNCOMMON := 3.7
const LEGACY_BASE_RARE := 0.3
const LEGACY_PITY_STEP := 0.2
const LEGACY_PITY_CAP := 2.0
const LEGACY_ELITE_UNCOMMON_MULT := 1.4
const LEGACY_ELITE_RARE_MULT := 4.0


func _simulate_legacy() -> Dictionary:
    var tally := {Card.RarityTier.COMMON: 0, Card.RarityTier.UNCOMMON: 0, Card.RarityTier.RARE: 0}
    var multi := {}
    for _run in RUNS:
        var rare_weight := 0.0  # RUN_START_RARE_WEIGHT
        for _act in 2:
            for source in _screens_per_act:
                var rares := 0
                if source == CardRarityDraw.Source.BOSS:
                    # The old boss branch bypassed the draw entirely and never touched pity.
                    tally[Card.RarityTier.RARE] += 3
                    rares = 3
                else:
                    # Typed explicitly: `source` is an untyped loop var, so `:=` off a
                    # comparison with it is the Variant-inference trap that hangs this harness.
                    var is_elite: bool = source == CardRarityDraw.Source.ELITE
                    var w_common := LEGACY_COMMON
                    var w_uncommon := LEGACY_UNCOMMON * (LEGACY_ELITE_UNCOMMON_MULT if is_elite else 1.0)
                    var w_rare := rare_weight * (LEGACY_ELITE_RARE_MULT if is_elite else 1.0)
                    var total := w_common + w_uncommon + w_rare
                    for _slot in 3:
                        var roll := randf_range(0.0, total)
                        var tier := Card.RarityTier.COMMON
                        if roll > w_common + w_uncommon:
                            tier = Card.RarityTier.RARE
                        elif roll > w_common:
                            tier = Card.RarityTier.UNCOMMON
                        tally[tier] += 1
                        if tier == Card.RarityTier.RARE:
                            rares += 1
                    rare_weight = LEGACY_BASE_RARE if rares > 0 else                         clampf(rare_weight + LEGACY_PITY_STEP, LEGACY_BASE_RARE, LEGACY_PITY_CAP)
                if not multi.has(source):
                    multi[source] = [0, 0, 0, 0]
                multi[source][rares] += 1
    return {"tally": tally, "multi": multi}


func _section_d_negative_control() -> void:
    print("")
    print("D. NEGATIVE CONTROL - the pre-change algorithm, same measurement")
    var old := _report(_simulate_legacy())
    var old_elite: Array = old["ELITE"]
    var old_normal: Array = old["NORMAL"]
    var new_elite: Array = _new_model["ELITE"]
    var new_normal: Array = _new_model["NORMAL"]
    _check("control reproduces clustered elite screens (2R >= 8%)", old_elite[2] >= 8.0,
        "control %.1f%% vs shipped %.2f%%" % [old_elite[2], new_elite[2]])
    _check("control also clusters normal screens (2R >= 1%)", old_normal[2] >= 1.0,
        "control %.2f%% vs shipped %.2f%%" % [old_normal[2], new_normal[2]])
    _check("shipped model cuts elite clustering by >=4x",
        new_elite[2] > 0.0 and old_elite[2] / new_elite[2] >= 4.0,
        "%.1fx" % (old_elite[2] / maxf(new_elite[2], 0.0001)))


func _section_e_shop() -> void:
    print("")
    print("E. shop rolls (reads the offset, never advances it)")
    var visits := 20000
    var rares := 0
    var at_least_one := 0
    for _v in visits:
        var got := 0
        for _slot in 5:
            if CardRarityDraw.roll_rarity(CardRarityDraw.Source.SHOP, RunStats.RARE_OFFSET_FLOOR) \
                    == Card.RarityTier.RARE:
                got += 1
        rares += got
        if got > 0:
            at_least_one += 1
    var per_slot := _pct(rares, visits * 5)
    var any_rate := _pct(at_least_one, visits)
    print("     rare per slot %.1f%%  |  visits holding >=1 Rare %.1f%%" % [per_slot, any_rate])
    # 0.09 + floor(-0.05) = 0.04 at run start, climbing with pity exactly like the reference.
    _check("shop rare per slot is ~4% at the offset floor", _near(per_slot, 4.0, 0.8),
        "%.2f%%" % per_slot)
    _check("a shop no longer guarantees a Rare", any_rate < 30.0, "%.1f%%" % any_rate)


# MUST run before section A. load()ing a class_name script by path (which A does, to force a
# compile) makes the text-scene parser miss that same script's ext_resource on its next parse,
# so run.tscn comes back script-less and this section reports a breakage that does not exist.
# Verified in isolation with a standalone probe: run.tscn loads, keeps res://scenes/run/run.gd
# and instantiates as a real Run with _start_run(). Nothing in the game loads run.gd by path
# ahead of run.tscn, so the ordering hazard is confined to harnesses like this one.
func _section_f_scenes() -> void:
    print("")
    print("F. consuming scenes still load")
    for path in [
        "res://scenes/run/run.tscn",
        "res://scenes/battle_reward/battle_reward.tscn",
        "res://scenes/shop/card_shop.tscn",
    ]:
        var packed := load(path)
        var ok := packed != null and packed is PackedScene
        _check("loads %s" % path.get_file(), ok)
        if ok:
            var state := (packed as PackedScene).get_state()
            var has_script := false
            for i in state.get_node_property_count(0):
                if state.get_node_property_name(0, i) == "script":
                    has_script = state.get_node_property_value(0, i) != null
            _check("  root keeps its script", has_script)
