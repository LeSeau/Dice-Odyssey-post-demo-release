extends Node2D
# Runtime verification for the 2026-07-28 audit-verdict batch. NOT committed (root-harness
# convention). Run:
#   "C:\Users\julie\Desktop\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64_console.exe" \
#       --path . res://debug_audit_changes.tscn --headless
# Prints PASS/FAIL per check, exits 0 if all pass.

var fails := 0
var checks := 0


func check(check_name: String, ok: bool, detail := "") -> void:
    checks += 1
    var suffix := ("  [" + detail + "]") if detail != "" else ""
    if ok:
        print("PASS  ", check_name, suffix)
    else:
        fails += 1
        print("FAIL  ", check_name, suffix)


func _ready() -> void:
    Global.tutorial_on = true  # mute achievement unlock toasts during forced states
    await get_tree().process_frame
    _test_dicelord_theft()
    _test_dragonpriest_picker()
    await _test_cursed_toss_and_trebuchet()
    _test_electrify()
    _test_trebuchet_card()
    print("---- %d checks, %d fails ----" % [checks, fails])
    get_tree().quit(1 if fails > 0 else 0)


func _test_dicelord_theft() -> void:
    var ai = load("res://enemies/leviathan/leviathan_enemy_ai.tscn").instantiate()
    add_child(ai)
    check("leviathan AI has 4 actions", ai.get_child_count() == 4, str(ai.get_child_count()))
    var theft = ai.get_node_or_null("dice_theft")
    check("dice_theft node present", theft != null)
    if theft == null:
        ai.queue_free()
        return
    check("theft is CONDITIONAL (type 0)", theft.type == 0, str(theft.type))
    check("get_child(0) still ink attack (fallback preserved)", ai.get_child(0).name == "ink_debuff_attack", ai.get_child(0).name)
    Global.current_act = 1
    Global.fight_turn = 1
    check("theft OFF in act 1", not theft.is_performable())
    Global.current_act = 2
    Global.fight_turn = 0
    check("theft OFF on first decision (turn idx 0)", not theft.is_performable())
    Global.fight_turn = 1
    check("theft ON act 2, turn idx 1", theft.is_performable())
    Global.fight_turn = 2
    check("theft OFF turn idx 2", not theft.is_performable())
    Global.fight_turn = 4
    check("theft ON turn idx 4 (every 3rd)", theft.is_performable())
    Global.blue_dice_max_amount = 2
    Global.red_dice_max_amount = 1
    Global.blue_dice_bonus_amount = 0
    Global.red_dice_bonus_amount = 0
    for t in ["green", "giant", "magma", "even", "odd", "mech", "evil"]:
        Global.set(t + "_dice_max_amount", 0)
        Global.set(t + "_dice_bonus_amount", 0)
    theft._steal_random_die()
    var stolen_total: int = Global.blue_dice_bonus_amount + Global.red_dice_bonus_amount
    var unowned_touched := false
    for t in ["green", "giant", "magma", "even", "odd", "mech", "evil"]:
        if int(Global.get(t + "_dice_bonus_amount")) != 0:
            unowned_touched = true
    check("steal = exactly -1 bonus on an OWNED type only", stolen_total == -1 and not unowned_touched,
        "blue %d red %d" % [Global.blue_dice_bonus_amount, Global.red_dice_bonus_amount])
    Global.blue_dice_bonus_amount = 0
    Global.red_dice_bonus_amount = 0
    Global.current_act = 1
    Global.fight_turn = 0
    ai.queue_free()


func _test_dragonpriest_picker() -> void:
    var ai = load("res://enemies/dragonpriest/dragonpriest_enemy_ai.tscn").instantiate()
    add_child(ai)
    check("DP has 2 actions (dead 11-attack node gone)", ai.get_child_count() == 2, str(ai.get_child_count()))
    Global.fight_turn = 0
    var a0 = ai.get_action()
    check("DP turn 0 -> Canalize (deterministic)", a0 != null and a0.name == "BuffAction", a0.name if a0 else "null")
    Global.fight_turn = 1
    var a1 = ai.get_action()
    check("DP turns 1+ -> steady attack via rules", a1 != null and a1.name == "FirstAttackAction", a1.name if a1 else "null")
    if a1 != null and a1.name == "FirstAttackAction":
        check("DP steady damage is 11", a1.damage == 11, str(a1.damage))
    Global.fight_turn = 0
    ai.queue_free()


func _test_cursed_toss_and_trebuchet() -> void:
    var fight = load("res://battles/tier_0_crab.tscn").instantiate()
    add_child(fight)
    await get_tree().process_frame
    var enemies := get_tree().get_nodes_in_group("enemies")
    check("real Enemy instantiated from battle scene", enemies.size() >= 1, str(enemies.size()))
    if enemies.is_empty():
        fight.queue_free()
        return
    var enemy = enemies[0]
    var card: Card = load("res://characters/warrior/cards/card_cursed_toss.tres").duplicate()
    var mods = enemy.modifier_handler
    Global.thrown_dice_bonus_fight = 0
    var hp0: int = enemy.stats.health
    card.apply_effects([enemy], mods)
    await get_tree().create_timer(1.8, false).timeout
    var dmg1: int = hp0 - enemy.stats.health
    # STALE-CHECK FIX 2026-08-18: the card throws an EVIL die now (faces 0/6/6/6, so a
    # 25% chance of the crack face), not an Even one. The old assertion failed on a
    # perfectly legal 0 roll.
    check("Cursed Toss = ONE Evil die (0 or 6 dmg)", dmg1 in [0, 6], str(dmg1))
    # STALE-CHECK FIX 2026-09-06: read the bonus off the card instead of keeping a copy.
    # This block asserted +2 for a week after Trebuchet was bumped to +3 on 2026-08-28.
    var treb: int = _trebuchet_bonus("res://characters/warrior/cards/card_trebuchet.tres")
    Global.thrown_dice_bonus_fight = treb
    var hp1: int = enemy.stats.health
    card.apply_effects([enemy], mods)
    await get_tree().create_timer(1.8, false).timeout
    var dmg2: int = hp1 - enemy.stats.health
    check("Trebuchet bonus rides the thrown die (+%d -> %d or %d)" % [treb, treb, 6 + treb],
            dmg2 in [treb, 6 + treb], str(dmg2))
    Global.thrown_dice_bonus_fight = 0
    fight.queue_free()


func _test_electrify() -> void:
    var card: Card = load("res://characters/warrior/cards/card_electrify.tres").duplicate()
    Global.odd_dice_current_amount = 0
    Global.odd_dice_bonus_amount = 0
    var blue_bonus_before: int = Global.blue_dice_bonus_amount
    card.apply_effects([self], null)
    # Retuned 2026-08-20 (Julien): 3 -> 2 Ricochet dice, and the Depleted downside was
    # dropped entirely because Depleted has no mechanical effect yet, so it was charging a
    # fake price. These two checks chased the old numbers until 2026-08-24.
    check("Electrify charges 2 Odd", Global.odd_dice_current_amount == 2, str(Global.odd_dice_current_amount))
    check("Electrify no longer depletes Blue", Global.blue_dice_bonus_amount == blue_bonus_before, str(Global.blue_dice_bonus_amount - blue_bonus_before))
    Global.odd_dice_current_amount = 0
    Global.odd_dice_bonus_amount = 0
    Global.blue_dice_bonus_amount = blue_bonus_before


func _test_trebuchet_card() -> void:
    var card: Card = load("res://characters/warrior/cards/card_trebuchet.tres").duplicate()
    Global.thrown_dice_bonus_fight = 0
    Global.blessing_cast_any_roll = false
    Global.roll_value = 3
    card.apply_effects([], null)
    check("Trebuchet gated below Min 6", Global.thrown_dice_bonus_fight == 0, str(Global.thrown_dice_bonus_fight))
    check("Trebuchet no exhaust on miss", not card.should_exhaust())
    Global.roll_value = 6
    card.apply_effects([], null)
    var base_bonus: int = _trebuchet_bonus("res://characters/warrior/cards/card_trebuchet.tres")
    check("Trebuchet +%d at roll 6" % base_bonus,
            Global.thrown_dice_bonus_fight == base_bonus, str(Global.thrown_dice_bonus_fight))
    check("Trebuchet exhausts on success", card.should_exhaust())
    Global.thrown_dice_bonus_fight = 0
    var plus: Card = load("res://characters/warrior/cards/card_trebuchet_plus.tres").duplicate()
    Global.roll_value = 6
    plus.apply_effects([], null)
    var plus_bonus: int = _trebuchet_bonus("res://characters/warrior/cards/card_trebuchet_plus.tres")
    check("Trebuchet+ gives +%d" % plus_bonus,
            Global.thrown_dice_bonus_fight == plus_bonus, str(Global.thrown_dice_bonus_fight))
    check("Trebuchet+ beats Trebuchet", plus_bonus > base_bonus,
            "%d vs %d" % [plus_bonus, base_bonus])
    Global.thrown_dice_bonus_fight = 0
    Global.roll_value = 0
    _test_upgrade_links()


func _test_upgrade_links() -> void:
    for base_path in ["res://characters/warrior/cards/card_bulletproof.tres",
            "res://characters/warrior/cards/card_trebuchet.tres"]:
        var base: Card = load(base_path)
        check("%s has upgrade link" % base.name, base.upgraded_version != null)
        if base.upgraded_version != null:
            check("%s -> %s upgraded flag" % [base.name, base.upgraded_version.name],
                base.upgraded_version.upgraded and base.can_be_upgraded())


# Reads Trebuchet's BONUS const off the card's script rather than keeping a second copy in
# here. get_script_constant_map() because a script constant is not reachable through get()
# and a statically typed Card var would not compile against a member Card does not declare.
func _trebuchet_bonus(path: String) -> int:
    var card: Card = load(path)
    var consts: Dictionary = card.get_script().get_script_constant_map()
    return int(consts.get("BONUS", 0))
