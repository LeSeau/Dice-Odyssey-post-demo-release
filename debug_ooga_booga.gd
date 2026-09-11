extends Node

# Verification harness for OOGA BOOGA (2026-09-09). Blessing that turns a MISSED requirement
# on the Red die into X2 damage to every enemy plus a Power reset.
#
# Section A is data (fields, upgrade wiring, pool, derived badge titles, title font size).
# Section B drives the REAL Card.play() path with playing_red_card set, which is exactly the
# state card_released_state.gd puts the game in when a Red roll resolves a socketed card - so
# the insertion point, the Berserker window and the player DMG_DEALT stack all get exercised.
#
# B2 is a NEGATIVE CONTROL: the identical miss with the Blessing uninstalled must deal ZERO.
# Without it, B1 passing would not prove the payout came from this feature at all.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_ooga_booga.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
const CARD := preload("res://characters/warrior/cards/card_ooga_booga.tres")
const CARD_PLUS := preload("res://characters/warrior/cards/card_ooga_booga_plus.tres")
const POOL := preload("res://characters/warrior/warrior_draftable_cards.tres")
const ST := preload("res://statuses/status_ooga_booga.tres")
const ST_PLUS := preload("res://statuses/status_ooga_booga_plus.tres")

var fails := 0
var _vp: SubViewport
var _hands_drawn := 0


func _ready() -> void:
    Events.player_hand_drawn.connect(func() -> void: _hands_drawn += 1)
    _section_a_data()
    await _section_b_behaviour()
    if fails == 0:
        print("[ooga] ALL PASS")
    else:
        print("[ooga] %d FAIL(S)" % fails)
    get_tree().quit(0 if fails == 0 else 1)


func _check(n: String, ok: bool, detail: String) -> void:
    if ok:
        print("[ooga] PASS  ", n, "  (", detail, ")")
    else:
        fails += 1
        print("[ooga] FAIL  ", n, "  (", detail, ")")


# ---------------------------------------------------------------------------- A: data ------
func _section_a_data() -> void:
    _check("A1 name", CARD.name == "Ooga Booga", CARD.name)
    _check("A2 type BLESSING", CARD.type == Card.Type.BLESSING, str(CARD.type))
    _check("A3 red_only", CARD.red_only, str(CARD.red_only))
    _check("A4 exhausts", CARD.exhausts, str(CARD.exhausts))
    _check("A5 rarity RARE", CARD.rarity_tier == Card.RarityTier.RARE, str(CARD.rarity_tier))
    _check("A6 requirement RED", CARD.requirement == Card.Requirement.RED, str(CARD.requirement))
    _check("A7 upgrade wired", CARD.upgraded_version == CARD_PLUS and CARD_PLUS.upgraded,
            "%s upgraded=%s" % [CARD_PLUS.name, CARD_PLUS.upgraded])
    # Pool-wide invariant since 2026-07-20: a "+" inherits its base rarity tier.
    _check("A8 plus rarity matches base", CARD_PLUS.rarity_tier == CARD.rarity_tier,
            "%d vs %d" % [CARD_PLUS.rarity_tier, CARD.rarity_tier])
    _check("A9 descriptions X2 and X3",
            CARD.description.contains("X2") and CARD_PLUS.description.contains("X3"),
            CARD.description)
    _check("A10 art present and shared", CARD.icon != null and CARD.icon == CARD_PLUS.icon,
            str(CARD.icon))

    var in_pool := 0
    var plus_in_pool := 0
    for c in POOL.cards:
        if c == CARD:
            in_pool += 1
        if c == CARD_PLUS:
            plus_in_pool += 1
    _check("A11 base in draftable pool once", in_pool == 1, "%d occurrence(s)" % in_pool)
    _check("A12 plus NOT draftable", plus_in_pool == 0, "%d" % plus_in_pool)

    # status_tooltip.gd derives the badge title from id.trim_suffix("_plus").capitalize().
    _check("A13 badge title base", ST.id.trim_suffix("_plus").capitalize() == "Ooga Booga",
            ST.id.trim_suffix("_plus").capitalize())
    _check("A14 badge title plus", ST_PLUS.id.trim_suffix("_plus").capitalize() == "Ooga Booga",
            ST_PLUS.id.trim_suffix("_plus").capitalize())
    _check("A15 status icons present", ST.icon != null and ST_PLUS.icon != null, "ok")
    _check("A16 status tooltips X2 and X3",
            ST.tooltip.contains("X2") and ST_PLUS.tooltip.contains("X3"), ST.tooltip)

    var s_base := CardUI.title_font_size_for(CARD.name)
    var s_plus := CardUI.title_font_size_for(CARD_PLUS.name)
    _check("A17 title renders at 12pt (known, accepted)", s_base == 12 and s_plus == 12,
            "base %dpt plus %dpt" % [s_base, s_plus])

    # The load-bearing one: RED is satisfied by ANY Red roll, so the card can never fire its
    # own payout. If this ever flips, Ooga Booga starts smashing the board on install.
    Global.dice_type = "red"
    Global.roll_value = 3
    _check("A18 cannot self-trigger", CARD.meets_requirement() and CARD_PLUS.meets_requirement(),
            "meets_requirement() true on a Red roll")


# ----------------------------------------------------------------- B: real play path --------
func _boot() -> Battle:
    _vp = SubViewport.new()
    _vp.size = Vector2i(1280, 720)
    _vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(_vp)
    var battle: Battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
    _vp.add_child(battle)
    var rh: RelicHandler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
    # HBoxContainer needs a Control ancestor or its layout collapses (documented harness trap).
    var host := Control.new()
    host.size = Vector2(400, 80)
    _vp.add_child(host)
    host.add_child(rh)
    var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
    battle.char_stats = warrior.create_instance()
    battle.relics = rh
    battle.battle_stats = load(FIGHT)
    battle.act_tier = 1
    var before := _hands_drawn
    battle.start_battle()
    while _hands_drawn == before:
        await get_tree().process_frame
    for i in 20:
        await get_tree().process_frame
    return battle


# Damage is measured as an HP delta, so a dying enemy silently caps the number (B5 first read
# 14 across 3 enemies - not even divisible by 3 - because earlier sections had killed things).
# Top every body up before each measurement so the delta is the full damage dealt.
func _topup_enemies(battle: Battle) -> void:
    for e in battle.get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(e) and e.stats != null:
            e.stats.max_health = 999
            e.stats.health = 999


func _enemy_hp(battle: Battle) -> int:
    var total := 0
    for e in battle.get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(e) and e.stats != null:
            total += int(e.stats.health)
    return total


# A pool card whose MIN gate a low roll cannot satisfy - the miss we are paying out on.
# Return type is deliberately untyped: POOL.cards is typed by SCRIPT PATH rather than by the
# class_name Card, so declaring `-> Card` here is a parse error (documented harness trap).
func _find_min_card():
    for c in POOL.cards:
        if c != null and c.requirement == Card.Requirement.MIN and c.requirement_number >= 6:
            return c
    return null


# Puts the game in the exact state card_released_state.gd creates while a Red roll resolves a
# socketed card, then plays the card for real through Card.play().
func _play_socketed(battle: Battle, card, roll: int) -> void:
    Global.dice_type = "red"
    Global.roll_value = roll
    Global.roll_history = [roll]
    Global.playing_red_card = true
    var player = Global.player
    # Card.play() takes a TYPED Array[Node]; a plain [player] literal is rejected at runtime
    # and the whole call silently does nothing.
    var targets: Array[Node] = []
    targets.append(player)
    card.play(targets, battle.char_stats, player.modifier_handler)
    Global.playing_red_card = false


func _section_b_behaviour() -> void:
    var battle := await _boot()
    # No := here: _find_min_card() is untyped (see its comment), and one Variant poisons
    # every later inference in the function (documented GDScript trap).
    var miss_card = _find_min_card()
    if miss_card == null:
        _check("B0 found a MIN card to miss", false, "none in pool")
        return
    var enemies := battle.get_tree().get_nodes_in_group("enemies").size()
    print("[ooga] miss card: %s (Min %d), %d enemies" % [miss_card.name, miss_card.requirement_number, enemies])

    # --- B2 runs FIRST, as the negative control: no Blessing installed means no payout.
    Global.red_whiff_damage_mult = 0
    _topup_enemies(battle)
    var hp0 := _enemy_hp(battle)
    _play_socketed(battle, miss_card, 3)
    await get_tree().process_frame
    var dealt_control := hp0 - _enemy_hp(battle)
    _check("B2 NEGATIVE CONTROL: miss with no Blessing deals 0", dealt_control == 0,
            "dealt %d" % dealt_control)

    # --- B1: installed, same miss, expect roll*2 to EVERY enemy.
    await get_tree().create_timer(1.6).timeout
    Global.red_whiff_damage_mult = 2
    _topup_enemies(battle)
    hp0 = _enemy_hp(battle)
    _play_socketed(battle, miss_card, 3)
    await get_tree().process_frame
    var dealt := hp0 - _enemy_hp(battle)
    _check("B1 miss pays roll*2 to all enemies", dealt == 3 * 2 * enemies,
            "dealt %d across %d enemies, expected %d" % [dealt, enemies, 3 * 2 * enemies])

    # --- B3: the Power reset the card promises. The Red branch defers its wipe ~1s.
    await get_tree().create_timer(1.6).timeout
    _check("B3 Power reset after the payout", Global.roll_value == 0,
            "roll_value=%d" % Global.roll_value)

    # --- B4: a card that MEETS its requirement must NOT pay out.
    Global.red_whiff_damage_mult = 2
    _topup_enemies(battle)
    hp0 = _enemy_hp(battle)
    _play_socketed(battle, miss_card, miss_card.requirement_number)
    await get_tree().process_frame
    var dealt_hit := hp0 - _enemy_hp(battle)
    _check("B4 a MET requirement does not trigger the payout", dealt_hit != 12 * enemies,
            "card dealt %d, which is its own damage rather than a payout" % dealt_hit)

    # --- B5: Strength applies, because the payout goes through the player DMG_DEALT stack.
    await get_tree().create_timer(1.6).timeout
    var muscle: Status = load("res://statuses/muscle.tres").duplicate()
    muscle.stacks = 4
    var se := StatusEffect.new()
    se.status = muscle
    se.execute([Global.player])
    await get_tree().process_frame
    Global.red_whiff_damage_mult = 2
    _topup_enemies(battle)
    hp0 = _enemy_hp(battle)
    _play_socketed(battle, miss_card, 3)
    await get_tree().process_frame
    var dealt_str := hp0 - _enemy_hp(battle)
    _check("B5 Strength scales the payout", dealt_str == (3 * 2 + 4) * enemies,
            "dealt %d, expected %d = (roll*2 + 4 Strength) x %d" % [dealt_str, (3 * 2 + 4) * enemies, enemies])

    _vp.queue_free()
    for i in 5:
        await get_tree().process_frame
