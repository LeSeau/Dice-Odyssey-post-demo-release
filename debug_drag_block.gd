extends Node2D

# Exercises Card.would_no_op_now() - the predicate behind the pick-up refusal
# (card_clicked_state.gd). The case that matters most is RED: socketing commits a card to a
# roll that hasn't happened, so gated cards must stay pick-up-able there or the Red gamble
# is gone. Boot as a SCENE, never --script (autoloads).

const POOL := "res://characters/warrior/warrior_draftable_cards.tres"

var passed := 0
var failed := 0


func check(label: String, cond: bool, detail: String = "") -> void:
    if cond:
        passed += 1
    else:
        failed += 1
        print("FAIL  %s   %s" % [label, detail])


func state(dice: String, roll: int, history: Array, ink: bool = false, red_left: int = 1) -> void:
    Global.dice_type = dice
    Global.roll_value = roll
    Global.roll_history = history
    Global.ink_active = ink
    Global.red_dice_current_amount = red_left


func blocked(c: Card) -> bool:
    return c.would_no_op_now()


func _live_labels(layer: Node) -> Array:
    var out := []
    for child in layer.get_children():
        # RichTextLabel, not Label: the message needs BBCode for the inline Power glyph.
        if child is RichTextLabel and not child.is_queued_for_deletion():
            out.append(child)
    return out


func _label_count(layer: Node) -> int:
    return _live_labels(layer).size()


func _first_label(layer: Node) -> RichTextLabel:
    var found := _live_labels(layer)
    return found[0] if not found.is_empty() else null


func _ready() -> void:
    var pool: Resource = load(POOL)
    var cards: Array = pool.cards

    var by_name := {}
    for c in cards:
        by_name[c.name] = c

    # representatives picked from the live pool rather than hardcoded, so a future
    # rebalance can't silently make this harness test nothing
    var celestial: Card = null
    var gated_min: Card = null
    var red_locked: Card = null
    var ungated: Card = null
    for c in cards:
        if celestial == null and c.can_play_without_dice:
            celestial = c
        if gated_min == null and c.requirement == Card.Requirement.MIN and not c.red_only:
            gated_min = c
        if red_locked == null and c.red_only:
            red_locked = c
        if ungated == null and c.requirement == Card.Requirement.NONE and not c.can_play_without_dice \
                and not c.red_only:
            ungated = c
    print("representatives: celestial=%s  gated_min=%s(%d)  red_only=%s  ungated=%s" % [
        celestial.name if celestial else "-",
        gated_min.name if gated_min else "-",
        gated_min.requirement_number if gated_min else -1,
        red_locked.name if red_locked else "-",
        ungated.name if ungated else "-"])

    var low_blow: Card = load("res://characters/warrior/cards/low_blow.tres")

    # --- 1. blue dice, a real roll of 5 -------------------------------------
    state("blue", 5, [5])
    check("Low Blow (Max 3) refused at 5", blocked(low_blow))
    check("ungated card allowed at 5", not blocked(ungated), ungated.name)
    check("Celestial always allowed", not blocked(celestial), celestial.name)
    check("red_only refused on blue", blocked(red_locked), red_locked.name)
    check("Min %d card refused at 5" % gated_min.requirement_number,
        blocked(gated_min) == (5 < gated_min.requirement_number), gated_min.name)

    # --- 2. requirement satisfied -------------------------------------------
    state("blue", 3, [3])
    check("Low Blow allowed at 3", not blocked(low_blow))

    # --- 3. nothing rolled yet ----------------------------------------------
    state("blue", 0, [])
    check("ungated card refused before any roll", blocked(ungated), ungated.name)
    check("Celestial still allowed before any roll", not blocked(celestial))

    # Evil's crack face IS a real roll, but the bank still came out 0, so an ordinary card
    # is refused all the same (Julien, 2026-09-10). This check asserted the opposite until
    # that ruling - if it ever flips back, the whole 0-Power section below goes with it.
    state("blue", 0, [0])
    check("crack-face roll is still refused (empty bank)", blocked(ungated), ungated.name)

    # --- 3b. 0 Power: the whole pool, blocked unless it opts in -------------
    # Two ways to land here in play: Evil's crack face, and a roll Weak ate whole
    # (dice.gd clamps the bank with max(0, ...) before Surge is added).
    var zero_allowed: Array[String] = []
    var zero_blocked := 0
    for c in cards:
        if c.can_play_without_dice or c.red_only:
            continue
        state("blue", 0, [0])
        if blocked(c):
            zero_blocked += 1
        else:
            zero_allowed.append(c.resource_path.get_file())
    zero_allowed.sort()
    print("0 Power: %d pool cards refused, %d allowed -> %s"
        % [zero_blocked, zero_allowed.size(), str(zero_allowed)])
    # The exact roster Julien signed off (2026-09-10): refuel, Power-from-nothing, dice
    # charging, flat effects, and anything scaling off something other than the bank. Anything
    # that resolves an X off Global.roll_value is absent by design. Recombobulate and Reinforce
    # are exempt too but live in the starting deck, not this pool, so they are checked by name
    # below instead.
    # Matched on resource file name, never on `name`: a rename pass is in flight on this
    # branch (card_low_roller.tres reads "Cataclysm" in HEAD) and display names move under
    # this harness mid-session. The file name is what actually identifies the card.
    var expected_zero := [
        "blaze.tres", "card_cadence.tres", "card_catalyst.tres", "card_catapult.tres",
        "card_coiled_spring.tres", "card_crescendo.tres", "card_electrify.tres",
        "card_emergency.tres", "card_finesse.tres", "card_jackpot_new.tres",
        "card_low_roller.tres", "card_necromancy.tres", "card_refinement.tres",
        "card_sleight.tres", "card_voodoo.tres", "card_war_ritual.tres"]
    check("0 Power allows exactly the cards that opted in",
        zero_allowed == expected_zero, str(zero_allowed))

    # Named spot-checks, so a future pool edit that drops Cataclysm still fails loudly
    # rather than quietly making the check above vacuous.
    var cataclysm: Card = load("res://characters/warrior/cards/card_low_roller.tres")
    var strike: Card = load("res://characters/warrior/cards/warrior_axe_attack1.tres")
    var recombobulate: Card = load("res://characters/warrior/cards/card_recombobulate.tres")
    state("blue", 0, [0])
    check("Cataclysm opts in at 0 Power", not blocked(cataclysm))
    check("Strike refused at 0 Power", blocked(strike))
    check("Recombobulate allowed at 0 Power", not blocked(recombobulate))
    var reinforce: Card = load("res://characters/warrior/cards/reinforce.tres")
    check("Reinforce allowed at 0 Power", not blocked(reinforce))
    var block_card: Card = load("res://characters/warrior/cards/warrior_block1.tres")
    check("Block refused at 0 Power", blocked(block_card))

    # An exemption must not smuggle a card past its own requirement: meets_requirement() is
    # still checked after the 0-Power branch. Mirror Blow shares its script with Mirror Blow+,
    # which is the one that actually opted in, so the ODD-gated base has to stay refused.
    var mirror: Card = load("res://characters/warrior/cards/card_mirror_blow.tres")
    check("exempt script still obeys its own requirement (Mirror Blow is ODD)", blocked(mirror))
    check("Celestial unaffected at 0 Power", not blocked(celestial), celestial.name)

    # The exemption must not leak backwards into "before the first roll" - Cataclysm pays
    # 12 - X, so a free 12 for no dice at all is exactly the hole has_active_roll() plugs.
    state("blue", 0, [])
    check("Cataclysm still refused before any roll", blocked(cataclysm))

    # --- 3c. the "+" side ---------------------------------------------------
    # Campfire upgrades put these straight into the deck, and 15 of the exemptions had to be
    # repeated in a separate _plus.gd rather than inherited. Nothing else in this harness ever
    # loads an upgraded card, so a twin that was missed would sit silently blocked.
    # Walks the starting deck too: Recombobulate+ and Reinforce+ are only reachable from there.
    var starter: Resource = load("res://characters/warrior/warrior_starting_deck.tres")
    var every_base: Array = cards.duplicate()
    for c in starter.cards:
        if not every_base.has(c):
            every_base.append(c)

    var plus_allowed: Array[String] = []
    var plus_checked := 0
    for c in every_base:
        var up: Card = c.upgraded_version
        if up == null or up.can_play_without_dice or up.red_only:
            continue
        plus_checked += 1
        state("blue", 0, [0])
        if not blocked(up):
            plus_allowed.append(up.resource_path.get_file())
    plus_allowed.sort()
    print("0 Power, upgraded side: %d checked, %d allowed -> %s"
        % [plus_checked, plus_allowed.size(), str(plus_allowed)])
    var expected_plus := [
        "blaze_plus.tres", "card_cadence_plus.tres", "card_catalyst_plus.tres",
        "card_catapult_plus.tres", "card_cogwork_plus.tres", "card_coiled_spring_plus.tres",
        "card_crescendo_plus.tres", "card_electrify_plus.tres", "card_emergency_plus.tres",
        "card_finesse_plus.tres", "card_jackpot_new_plus.tres", "card_low_roller_plus.tres",
        "card_mirror_blow_plus.tres", "card_necromancy_plus.tres",
        "card_recombobulate_plus.tres", "card_refinement_plus.tres", "card_voodoo_plus.tres",
        "card_war_ritual_plus.tres", "reinforce_plus.tres"]
    check("0 Power: the upgraded twins match their bases",
        plus_allowed == expected_plus, str(plus_allowed))

    # ...and it must not leak forward either: with Power banked it is an ordinary card again.
    state("blue", 4, [4])
    check("Cataclysm judged normally with Power banked", not blocked(cataclysm))

    # Negative control: without the opt-in, Cataclysm would be refused like everything else.
    # If this ever passes, plays_at_zero_power() has stopped being consulted.
    state("blue", 0, [0])
    check("control: the base predicate refuses at 0 Power",
        Card.new().plays_at_zero_power() == false)

    # --- 4. RED: the gamble must survive ------------------------------------
    state("red", 0, [], false, 1)
    check("RED: gated card still socketable", not blocked(gated_min), gated_min.name)
    check("RED: Low Blow still socketable", not blocked(low_blow))
    check("RED: red_only card socketable", not blocked(red_locked), red_locked.name)
    check("RED: ungated socketable", not blocked(ungated), ungated.name)

    state("red", 0, [], false, 0)
    check("RED with no die left: refused", blocked(low_blow))

    # --- 5. ink hides the number, so never pre-judge ------------------------
    state("blue", 5, [5], true)
    check("Inked: gated card allowed", not blocked(low_blow))
    check("Inked: Min card allowed", not blocked(gated_min), gated_min.name)

    # --- 6. sweep: every pool card at every roll, blue dice ------------------
    # the refusal must agree with meets_requirement() once a roll exists
    #
    # In-hand passives (Dice Aura, Blood Pact) override would_no_op_now() to refuse
    # unconditionally, so they sit outside that contract by design and have to come out of
    # the sweep - otherwise they alone report ~40 mismatches and the check cries wolf. They
    # are found rather than named: a card refused at all 20 rolls while meeting its
    # requirement at some of them can only be an unconditional override. The count is
    # asserted so a THIRD such card cannot appear unnoticed and quietly shrink the sweep.
    #
    # This exclusion is unrelated to the 0-Power rule: the sweep only ever rolls 1..20, so
    # the new empty-bank branch is never reached here. It was failing before that change too.
    var always_refused: Array[String] = []
    for c in cards:
        if c.can_play_without_dice or c.red_only:
            continue
        var refused_every_roll := true
        var met_at_least_once := false
        for roll in range(1, 21):
            state("blue", roll, [roll])
            if c.meets_requirement():
                met_at_least_once = true
            if not blocked(c):
                refused_every_roll = false
        if refused_every_roll and met_at_least_once:
            always_refused.append(c.name)
    always_refused.sort()
    check("only the known in-hand passives refuse unconditionally",
        always_refused == ["Blood Pact", "Dice Aura"], str(always_refused))

    var mismatches := 0
    for c in cards:
        if c.can_play_without_dice or c.red_only or always_refused.has(c.name):
            continue
        for roll in range(1, 21):
            state("blue", roll, [roll])
            var want: bool = not c.meets_requirement()
            if blocked(c) != want:
                mismatches += 1
                if mismatches <= 5:
                    print("   mismatch %s roll=%d blocked=%s meets=%s"
                        % [c.name, roll, blocked(c), c.meets_requirement()])
    check("full pool sweep agrees with meets_requirement()", mismatches == 0,
        "%d mismatches" % mismatches)

    # --- 7. the feedback itself must not error at runtime -------------------
    # Exercises play_pickup_refusal() on a REAL CardUI: catches tween-API misuse, a wrong
    # SFXPlayer arg order, or a null node reference - none of which gdtoolkit can see.
    # the message parents itself to the "ui_layer" group (BattleUI in the real game)
    var fake_ui_layer := CanvasLayer.new()
    fake_ui_layer.add_to_group("ui_layer")
    add_child(fake_ui_layer)

    var ui_scene: PackedScene = load("res://scenes/card_ui/card_ui.tscn")
    var ui := ui_scene.instantiate()
    add_child(ui)                      # add_child BEFORE .card, as every real call site does
    ui.card = low_blow
    await get_tree().process_frame

    # requirement failure -> shake + ribbon pulse + "requirements" wording
    state("blue", 5, [5])
    check("real CardUI reports blocked", ui.is_drag_blocked())
    ui.play_pickup_refusal()
    await get_tree().process_frame
    check("shake displaced the card body", ui.card_background.position.x != 0.0,
        str(ui.card_background.position))
    var msg: RichTextLabel = _first_label(fake_ui_layer)
    check("refusal message shown", msg != null)
    check("requirement wording", msg != null and msg.text.contains("Card requirements are not met"),
        msg.text if msg else "<none>")
    check("requirement line carries no glyph",
        msg != null and not msg.text.contains(KeywordColorizer.POWER_GLYPH_PATH),
        msg.text if msg else "<none>")

    # zero power -> "need Power" wording, and the previous label is REPLACED, not stacked
    state("blue", 0, [])
    ui.play_pickup_refusal()
    await get_tree().process_frame
    await get_tree().process_frame
    check("only one message on screen", _label_count(fake_ui_layer) == 1,
        str(_label_count(fake_ui_layer)))
    msg = _first_label(fake_ui_layer)
    check("no-power wording", msg != null and msg.text.contains("Power to play this card"),
        msg.text if msg else "<none>")
    check("no-power line embeds the Power glyph",
        msg != null and msg.text.contains(KeywordColorizer.POWER_GLYPH_PATH),
        msg.text if msg else "<none>")
    check("glyph sized by the font_size + 2 convention",
        msg != null and msg.text.contains("[img=%d]" % (CardUI.REFUSAL_MSG_FONT_SIZE + 2)),
        msg.text if msg else "<none>")

    # let every tween finish and confirm it all settles back home
    await get_tree().create_timer(2.0).timeout
    check("card body returns to rest", is_equal_approx(ui.card_background.position.x, 0.0),
        str(ui.card_background.position))
    check("ribbon returns to white", ui.requirement_panel.modulate.is_equal_approx(Color.WHITE),
        str(ui.requirement_panel.modulate))
    check("ribbon returns to scale 1", ui.requirement_panel.scale.is_equal_approx(Vector2.ONE),
        str(ui.requirement_panel.scale))
    check("message cleaned itself up", _label_count(fake_ui_layer) == 0,
        str(_label_count(fake_ui_layer)))
    ui.queue_free()

    state("blue", 0, [])
    print("=========================================")
    print("passed=%d  failed=%d" % [passed, failed])
    print("=========================================")
    get_tree().quit()
