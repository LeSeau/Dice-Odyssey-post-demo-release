extends Node

# Rename pass verification (2026-09-07). Boots a real scene so the autoloads exist - a
# `--script` run has no Global/Events and every .tres silently loads its script properties
# at their defaults, which would make every name read back empty.
#
#   Godot_v4.3-stable_win64_console.exe --path . --headless res://debug_card_rename_check.tscn
#
# What it pins:
#   A  every renamed card (base AND "+") reads back its new name
#   B  no OLD name survives anywhere in the draftable pool
#   C  no two pool cards share a name (the Haste collision that started this)
#   D  every renamed status's badge TITLE follows, since status_tooltip derives it from
#      status.id via capitalize() - the whole reason the ids were renamed too
#   E  TITLE_OVERRIDES is empty and _title_for still works without it

const POOL := "res://characters/warrior/warrior_draftable_cards.tres"

var _fail := 0
var _pass := 0

func _check(label: String, ok: bool, detail := "") -> void:
    if ok:
        _pass += 1
        print("  ok   %s" % label)
    else:
        _fail += 1
        print("  FAIL %s   %s" % [label, detail])

# base .tres path -> [expected base name, expected + name]
const RENAMED := {
    "card_rigged":         ["Trickery", "Trickery+"],
    "card_overclock":      ["Haste", "Haste+"],
    "card_dead_weight":    ["Dice Aura", "Dice Aura+"],
    "card_blood_oath":     ["Blood Pact", "Blood Pact+"],
    "card_coiled_spring":  ["Buzzer Shot", "Buzzer Shot+"],
    "card_jackpot_new":    ["Sixplosion", "Sixplosion+"],
    "card_tidal_force":    ["Pulverize", "Pulverize+"],
    "card_opening_gambit": ["Dice Echo", "Dice Echo+"],
    "card_hardened_grip":  ["Die Hard", "Die Hard+"],
    "card_ringer":         ["Amplify", "Amplify+"],
    "card_dual_cannon":    ["Red Cannon", "Red Cannon+"],
    "card_forge":          ["Forge", "Forge+"],
    "card_quicksilver":    ["Malleable", "Malleable+"],
    "card_dicelord_gift":  ["Anarchy", "Anarchy+"],
}

const OLD_NAMES := [
    "Rigged", "Overclock", "Dead Weight", "Blood Oath", "Coiled Spring", "Jackpot",
    "Tidal Force", "Opening Gambit", "Hardened Grip", "Ringer", "Dual Cannon",
    "Grindstone", "Quicksilver", "Dicelord's Gift",
]

# status .tres -> expected badge title (what status_tooltip._title_for produces)
const STATUS_TITLES := {
    "res://statuses/status_coiled_spring.tres":     "Buzzer Shot",
    "res://statuses/status_dicelord_gift.tres":     "Anarchy",
    "res://statuses/status_dicelord_gift_plus.tres":"Anarchy",
    "res://statuses/status_hardened_grip.tres":     "Die Hard",
    "res://statuses/status_opening_gambit.tres":    "Dice Echo",
    "res://statuses/status_forge.tres":             "Forge",
    "res://statuses/status_second_socket.tres":     "Red Cannon",
    "res://statuses/status_quicksilver.tres":       "Malleable",
    # untouched control: Steady Hand kept its name, so its badge must NOT have moved
    "res://statuses/status_steady_hand.tres":       "Steady Hand",
}

func _ready() -> void:
    await get_tree().process_frame

    print("\n--- A: renamed cards read back their new name ---")
    for base_id in RENAMED:
        var want: Array = RENAMED[base_id]
        var base: Card = load("res://characters/warrior/cards/%s.tres" % base_id)
        _check("%s -> %s" % [base_id, want[0]], base != null and base.name == want[0],
                "got '%s'" % (base.name if base != null else "<null>"))
        var up: Card = base.upgraded_version if base != null else null
        _check("%s+ -> %s" % [base_id, want[1]], up != null and up.name == want[1],
                "got '%s'" % (up.name if up != null else "<null>"))

    print("\n--- B/C: the draftable pool ---")
    var pool = load(POOL)
    _check("pool loads", pool != null and not pool.cards.is_empty(),
            "%d cards" % (pool.cards.size() if pool != null else -1))

    var seen := {}
    var dupes: Array[String] = []
    var stale: Array[String] = []
    for c in pool.cards:
        if c == null:
            continue
        if seen.has(c.name):
            dupes.append(c.name)
        seen[c.name] = true
        if OLD_NAMES.has(c.name):
            stale.append(c.name)
    _check("no OLD card name left in the pool", stale.is_empty(), str(stale))
    _check("no two pool cards share a name", dupes.is_empty(), str(dupes))
    _check("pool still has 78 cards", pool.cards.size() == 78, str(pool.cards.size()))

    print("\n--- D: status badge titles follow the card names ---")
    var tooltip_script = load("res://scenes/ui/status_tooltip.gd")
    for path in STATUS_TITLES:
        var st: Status = load(path)
        if st == null:
            _check(path, false, "resource missing")
            continue
        var base_id: String = st.id.trim_suffix("_plus")
        var override: String = tooltip_script.TITLE_OVERRIDES.get(base_id, "")
        var title: String = override if override != "" else base_id.capitalize()
        _check("%s badge reads '%s'" % [path.get_file(), STATUS_TITLES[path]],
                title == STATUS_TITLES[path], "got '%s' from id '%s'" % [title, st.id])

    print("\n--- E: TITLE_OVERRIDES ---")
    _check("TITLE_OVERRIDES is empty (no punctuation names left)",
            tooltip_script.TITLE_OVERRIDES.is_empty(),
            str(tooltip_script.TITLE_OVERRIDES))

    print("\n=== %d checks, %d FAIL ===" % [_pass + _fail, _fail])
    get_tree().quit()
