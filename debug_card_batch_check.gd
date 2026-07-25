extends Node

# Throwaway verification harness for the 2026-07-25 card-adjustment batch.
# Boots a REAL scene (never --script: autoloads must exist or every .tres silently loads
# its script properties as defaults - see CLAUDE.md).
#   Godot_v4.3-stable_win64_console.exe --path . --headless res://debug_card_batch_check.tscn

const C := "res://characters/warrior/cards/"

var fails: Array[String] = []


func _ready() -> void:
    _check_cards()
    _check_pool()
    _check_plumbing()
    _show_colorized()
    print("\n================ %s (%d checks failed) ================" % [
            "FAIL" if fails.size() > 0 else "ALL PASS", fails.size()])
    for f in fails:
        print("  FAIL: ", f)
    get_tree().quit(1 if fails.size() > 0 else 0)


func _expect(label: String, actual, expected) -> void:
    if actual != expected:
        fails.append("%s -> got %s, expected %s" % [label, str(actual), str(expected)])
    else:
        print("  ok  %s = %s" % [label, str(actual)])


func _card(file: String) -> Card:
    var c = load(C + file)
    if c == null:
        fails.append("could not load " + file)
    return c


func _check_cards() -> void:
    print("\n--- card data ---")
    var m := _card("card_meteor.tres")
    _expect("Meteor.desc", m.description, "Deal X damage. Throw a Giant Dice that deals damage equal to its roll")
    _expect("Meteor.upgraded_version", m.upgraded_version != null, true)
    _expect("Meteor+.desc", _card("card_meteor_plus.tres").description,
            "Deal X damage. Throw a Giant Dice that deals damage equal to its roll")

    var ct := _card("card_cursed_toss.tres")
    _expect("CursedToss.desc", ct.description, "Throw 2 Blue Dice. Each deals damage equal to its roll")
    _expect("CursedToss.celestial", ct.can_play_without_dice, true)
    _expect("CursedToss.rarity(SUPPORT=no auto reset)", ct.rarity, Card.Rarity.SUPPORT)
    _expect("CursedToss.upgraded_version", ct.upgraded_version != null, true)
    _expect("CursedToss+.desc", _card("card_cursed_toss_plus.tres").description,
            "Throw 3 Blue Dice. Each deals damage equal to its roll")

    _expect("PixieVolley.desc", _card("card_pixie_volley.tres").description,
            "Throw X Pixie Dice at random enemies. Each deals damage equal to its roll")
    _expect("PixieVolley+.desc", _card("card_pixie_volley_plus.tres").description,
            "Throw X Pixie Dice at random enemies. Each deals damage equal to its roll")

    _expect("LowRoller.desc", _card("card_low_roller.tres").description, "Deal 12 - X damage")
    _expect("LowRoller+.desc", _card("card_low_roller_plus.tres").description, "Deal 15 - X damage")

    _expect("Stampede.desc", _card("card_stampede.tres").description,
            "Deal X damage. If you rolled at least 5 Dice this turn, deal it twice")
    _expect("Stampede+.desc", _card("card_stampede_plus.tres").description,
            "Deal X damage. If you rolled at least 5 Dice this turn, deal it three times")

    _expect("CoiledSpring.celestial", _card("card_coiled_spring.tres").can_play_without_dice, false)
    _expect("CoiledSpring+.celestial", _card("card_coiled_spring_plus.tres").can_play_without_dice, false)

    var k := _card("card_kickstart.tres")
    _expect("Kickstart.desc", k.description, "Gain X Strength")
    _expect("Kickstart.requirement", k.requirement, Card.Requirement.MAX)
    _expect("Kickstart.requirement_number", k.requirement_number, 3)
    _expect("Kickstart.tags", k.tags, "Strength")
    _expect("Kickstart.script", k.get_script().resource_path, C + "kickstart.gd")
    _expect("Kickstart.upgraded_version", k.upgraded_version != null, true)
    var kp := _card("card_kickstart_plus.tres")
    _expect("Kickstart+.requirement_number", kp.requirement_number, 5)
    _expect("Kickstart+.script(reuses base)", kp.get_script().resource_path, C + "kickstart.gd")
    _expect("Kickstart+.desc", kp.description, "Gain X Strength")

    _expect("Blaze.desc", _card("blaze.tres").description, "Add 7 to your Power. Gain Weak 1")
    _expect("Blaze+.desc", _card("blaze_plus.tres").description, "Add 9 to your Power. Gain Weak 1")

    _expect("Windfall.upgraded_version", _card("card_windfall.tres").upgraded_version != null, true)

    # Blackjack popup number: the amount the script builds must be 999 for any normal enemy.
    var quake = load("res://statuses/status_earthquake.tres")
    _expect("Earthquake status loads", quake != null, true)


func _check_pool() -> void:
    print("\n--- draftable pool ---")
    var pool = load("res://characters/warrior/warrior_draftable_cards.tres")
    if pool == null:
        fails.append("draftable pool failed to load")
        return
    var ids: Array[String] = []
    var nulls := 0
    for c in pool.cards:
        if c == null:
            nulls += 1
        else:
            ids.append(c.id)
    _expect("pool has no null entries", nulls, 0)
    _expect("pool size (was 87, minus Fastball + Slash)", pool.cards.size(), 85)
    _expect("fastball cut", ids.has("card_fastball"), false)
    _expect("slash cut", ids.has("card_slash"), false)
    for keep in ["card_meteor", "card_cursed_toss", "card_pixie_volley", "card_low_roller",
            "card_stampede", "card_coiled_spring", "card_kickstart", "card_windfall"]:
        _expect("pool still has " + keep, ids.has(keep), true)
    _expect("no duplicate ids", ids.size(), _unique(ids).size())


func _unique(a: Array[String]) -> Array[String]:
    var seen: Array[String] = []
    for x in a:
        if not seen.has(x):
            seen.append(x)
    return seen


func _check_plumbing() -> void:
    print("\n--- plumbing ---")
    # dice.gd must still compile (the throw clamp + coin anchor edits).
    var dice_script = load("res://scenes/dices/dice.gd")
    _expect("dice.gd compiles", dice_script != null and dice_script.can_instantiate(), true)

    # coin_flip must now carry the target, and the listener must accept 3 args or it
    # silently no-ops at emit time (Godot 4 signal-arity gotcha).
    var arg_count := -1
    for s in Events.get_signal_list():
        if s.name == "coin_flip":
            arg_count = s.args.size()
    _expect("Events.coin_flip arg count", arg_count, 3)

    # Thrown Blue Dice faces (Cursed Toss's new payload) - d6, no zero face.
    var blue: Array = Card.thrown_faces_for("blue")
    _expect("blue thrown faces", blue, [1, 2, 3, 4, 5, 6])


# Not assertions - just eyeballs on how each reworded description actually renders, since
# the colorizer's step-2 "absorb" rule can pull a keyword into a dice colour.
func _show_colorized() -> void:
    print("\n--- colorized descriptions ---")
    for f in ["card_meteor.tres", "card_cursed_toss.tres", "card_cursed_toss_plus.tres",
            "card_pixie_volley.tres", "card_low_roller.tres", "card_stampede.tres",
            "card_stampede_plus.tres", "card_kickstart.tres", "blaze.tres"]:
        var c := _card(f)
        if c != null:
            print("  %-28s %s" % [c.name, c.get_colorized_description(c.description)])
