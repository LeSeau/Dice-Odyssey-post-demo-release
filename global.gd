extends Node

# Custom cursor - thick/bulky hooked-arrow shape (deliberately not a literal die, to stay
# distinct from both the OS cursor and other engines' dice-shaped ones) with a gold flat
# fill and an emerald accent near the tail, matching the game's gold-trim UI language.
# Idle and pressed textures were cropped from a SHARED bounding box (union of both
# images' alpha bboxes, not each image's own) before resizing, specifically so the tip
# lands at the same pixel in both - swapping textures on click can't jitter the hotspot.
# Hotspot sits right at that tip (near the top-left of the cropped asset), not the visual
# center of the icon.
const CURSOR_TEXTURE := preload("res://assets/images/cursor_pointer.png")
const CURSOR_TEXTURE_PRESSED := preload("res://assets/images/cursor_pointer_pressed.png")
const CURSOR_HOTSPOT := Vector2(3, 1)

# Thrown-dice cards (Meteor, Fastball, Cursed Toss...): one shared flight time so the card
# scripts (which schedule the damage landing, Card._land_thrown_die) and dice.gd (which
# animates the throw on Events.dice_thrown) stay in sync. FLIGHT_TIME is the TOTAL time
# from emit to landing - dice.gd carves the windup AND the bash beats (rise above the
# enemy, face-lock hang, downward slam) out of that budget, never adds on top. Cards never
# need to know about the split; they schedule at FLIGHT_TIME (+ per-die stagger via
# dice_throw_volley_stagger below) and stay synced automatically.
const DICE_THROW_WINDUP_TIME := 0.26
const DICE_THROW_FLIGHT_TIME := 0.95
# Per-die impact spacing for a volley. Bumped 0.22 -> 0.28 (Julien, 2026-07-24 v4: "need
# a bit more time to see which dice roll what" on Dice Avalanche) - each hit gets a
# clearer read before the next lands.
const DICE_THROW_STAGGER := 0.28
# Big volleys compress their per-die spacing so the whole barrage stays under this many
# seconds between FIRST and LAST impact (<=8 dice keep the full stagger untouched); scaled
# up with the base bump so a 9-die Avalanche also gets a touch more room per hit.
const DICE_THROW_VOLLEY_SPAN := 1.95
# ...but never below this floor - past ~15 dice the sequence becomes a fast drumroll
# instead of stretching on forever.
const DICE_THROW_STAGGER_MIN := 0.12
# Double or Nothing: how long the coin spins before the outcome resolves (damage or nothing).
const COIN_FLIP_TIME := 0.6


# Per-die spacing for a volley of `count` thrown dice. THE single source of truth for
# "when does die i land": card scripts schedule damage at
# FLIGHT_TIME + dice_throw_volley_stagger(n) * i and dice.gd delays each die's visual by
# the same stagger, so the hit and the bash can never drift apart. Sequenced deliberately
# slower than the old 0.15 mush (Julien, 2026-07-24: "bam bam bam ... with clarity on
# which dice is dealing what damage").
func dice_throw_volley_stagger(count: int) -> float:
    if count <= 1:
        return DICE_THROW_STAGGER
    return clampf(DICE_THROW_VOLLEY_SPAN / float(count - 1),
            DICE_THROW_STAGGER_MIN, DICE_THROW_STAGGER)


# Is a card with this id sitting in the player's hand right now? Scans the live Hand rather
# than any cached set - see the IN_HAND_* consts for why.
func in_hand(card_id: String) -> bool:
    var tree := get_tree()
    if tree == null:
        return false
    var hand := tree.get_first_node_in_group("hand")
    if hand == null:
        return false
    for child in hand.get_children():
        if child is CardUI and child.card != null and child.card.id == card_id:
            return true
    return false


# Extra Power a roll gets purely from cards being HELD (never from playing them).
func in_hand_roll_bonus(dice_type: String) -> int:
    var bonus := 0
    # Blood Oath: 2 (Julien, 2026-08-20 - same figure as the Blood Sword relic; they stack).
    # Both versions can be held at once, so these add rather than pick the larger.
    if dice_type == "red":
        if in_hand(IN_HAND_RED_AURA):
            bonus += 2
        if in_hand(IN_HAND_RED_AURA_PLUS):
            bonus += 3
    # Dead Weight is Loaded 1 while held, and Loaded applies to every type. The + keeps the
    # same Loaded 1 and adds its Strength through in_hand_damage_bonus() instead.
    if in_hand(IN_HAND_DEAD_WEIGHT) or in_hand(IN_HAND_DEAD_WEIGHT_PLUS):
        bonus += 1
    return bonus


# Flat damage a card gets purely from cards being HELD - the damage-side twin of
# in_hand_roll_bonus(). Applied once, inside ModifierHandler.get_modified_value() for the
# player's DMG_DEALT, so it behaves exactly like a Strength stack: every card's real damage
# AND its dynamic-description preview pick it up without either knowing this exists.
func in_hand_damage_bonus() -> int:
    var bonus := 0
    if in_hand(IN_HAND_DEAD_WEIGHT_PLUS):
        bonus += 1
    return bonus


# Block granted per natural 6 by Talisman being held. 0 when neither version is in hand.
func in_hand_six_block() -> int:
    var block := 0
    if in_hand(IN_HAND_TALISMAN):
        block += TALISMAN_SIX_BLOCK
    if in_hand(IN_HAND_TALISMAN_PLUS):
        block += TALISMAN_PLUS_SIX_BLOCK
    return block


# What faces `dice_type` can land on RIGHT NOW: a card's fight-scoped edit wins over the
# infusion's set, which wins over the printed faces. Card.thrown_faces_for() and the Scout
# preview both route through here so a trimmed die can never show a face it cannot roll.
func current_face_values(dice_type: String) -> Array:
    if face_overrides.has(dice_type):
        return face_overrides[dice_type]
    var infused: Array = DiceInfusions.roll_values_override(dice_type)
    var values: Array = Card.DICE_FACE_VALUES.get(dice_type, [1, 2, 3, 4, 5, 6])
    if not infused.is_empty():
        values = infused
    # Talisman used to trim the lowest face here. Its identity moved to "every natural 6
    # grants Block" (Julien, 2026-08-20), which lives at the last_roll == 6 check in dice.gd,
    # so this function is back to being purely about card/infusion face edits.
    return values


# Called once per thrown/conjured die at the moment it LANDS (card.gd::_on_thrown_die_landed
# plus the air-land callbacks in windfall/rampart/kickstart). Design line (Julien,
# 2026-07-23): a thrown die counts as a die you ROLLED - fight/turn dice counters, the run
# scoreboard, and the per-die opt-in triggers on Events.dice_thrown_landed (Crown, Snake
# Eyes Charm, Hardened Grip, Greedy...) - but it never joins the Power chain: roll_value,
# roll_history, last_roll and next-roll modifiers stay untouched (Recombobulate must not
# refund it, a throw must not eat a Scouted roll).
func report_thrown_die_landed(dice_type: String, value: int) -> void:
    fight_dice_rolled += 1
    dice_amount_rolled_this_turn += 1
    dice_types_rolled_this_turn[dice_type] = true
    # A thrown 6 counts for Jackpot/Effigy, same as it already counts for Hunting Bow.
    if value == 6:
        sixes_rolled_this_fight += 1
    # Same ordering as dice.gd's real-roll path: counter first, then the report/emit, so
    # listeners read the already-incremented counters (Turbo Mode counts thrown dice too).
    AchievementManager.report_dice_rolled_this_turn(dice_amount_rolled_this_turn)
    run_stat_dice_rolled += 1
    Events.dice_thrown_landed.emit(dice_type, value)


# App-scoped player settings (volumes, fullscreen) - loaded once at startup and
# applied to the audio buses/window here; the pause menu updates them live afterwards
# through SettingsManager. Deliberately NOT part of reset_run_state()/the run save:
# these belong to the player, not to a run.
func _ready() -> void:
    # ALWAYS: the pressed-state swap below (_input) must keep working even while the
    # tree is paused (pause menu, map consult, battle-over panel all pause it) - same
    # reasoning as AchievementManager's toast layer.
    process_mode = Node.PROCESS_MODE_ALWAYS
    SettingsManager.load_and_apply()
    Input.set_custom_mouse_cursor(CURSOR_TEXTURE, Input.CURSOR_ARROW, CURSOR_HOTSPOT)


# Global left-click press/release swaps the whole cursor to a visually "active" variant -
# read-only observation, never consumes the event, so it can't interfere with the actual
# click going to whatever button/card/dice is under the mouse.
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        var texture := CURSOR_TEXTURE_PRESSED if event.pressed else CURSOR_TEXTURE
        Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, CURSOR_HOTSPOT)


# --- Floating tooltip lifetime -------------------------------------------------------------
# Every hover tooltip in the game is instantiated on mouse_entered and parented to
# get_tree().root - NOT to the node that spawned it - so it can render above every CanvasLayer
# (z_index never crosses a CanvasLayer boundary). The cost of that is there is nothing tying
# the tooltip's life to its owner's: if the owner dies or its screen goes away while the
# tooltip is up, mouse_exited never fires and the tooltip sits on the root forever, surviving
# into the map, the shop, the next fight. That is the "This enemy will attack you" popup that
# never left (reported 2026-08-03: an enemy died mid-hover, taking its IntentUI - and with it
# the coroutine that was supposed to time the tooltip out - with it).
#
# Per-site cleanup (_exit_tree, free-before-respawn) is still done where it belongs, but there
# are ~30 spawn sites and every one of them is one refactor away from leaking again. So the
# rule is enforced centrally instead: a tooltip registered here is freed as soon as its owner
# is gone, out of the tree, or invisible. Spawn tooltips with Global.add_tooltip() and this is
# handled - never call get_tree().root.add_child() on a tooltip directly.
const TOOLTIP_GROUP := "floating_tooltip"
const TOOLTIP_OWNER_META := "tooltip_owner"
# 6 frames ~= 0.1s at 60fps. This is a safety net, not the primary cleanup path, so it does
# not need to run every frame - and get_nodes_in_group() allocates.
const TOOLTIP_SWEEP_FRAMES := 6

var _tooltip_sweep_countdown := TOOLTIP_SWEEP_FRAMES


# Parents `tooltip` under the tree root (as every tooltip needs) and ties its life to
# `tooltip_owner` - typically the node whose mouse_entered spawned it, or the specific child
# that owns the hover (a badge, a button) when that node can be hidden on its own.
func add_tooltip(tooltip: Node, tooltip_owner: Node) -> void:
    tooltip.add_to_group(TOOLTIP_GROUP)
    tooltip.set_meta(TOOLTIP_OWNER_META, weakref(tooltip_owner))
    get_tree().root.add_child(tooltip)


func _process(_delta: float) -> void:
    _tooltip_sweep_countdown -= 1
    if _tooltip_sweep_countdown > 0:
        return
    _tooltip_sweep_countdown = TOOLTIP_SWEEP_FRAMES
    for tooltip in get_tree().get_nodes_in_group(TOOLTIP_GROUP):
        if tooltip.is_queued_for_deletion():
            continue
        if not _tooltip_owner_is_live(tooltip):
            tooltip.queue_free()


func _tooltip_owner_is_live(tooltip: Node) -> bool:
    # weakref, not the node itself: a plain reference in meta would keep a freed node's slot
    # alive and is_instance_valid() on it is exactly the check we are trying to avoid relying on.
    var ref = tooltip.get_meta(TOOLTIP_OWNER_META, null)
    if ref == null:
        return true  # not registered through add_tooltip() - not ours to police
    var tooltip_owner = ref.get_ref()
    if tooltip_owner == null or not is_instance_valid(tooltip_owner):
        return false
    if not tooltip_owner.is_inside_tree():
        return false
    # Covers the screen being hidden rather than freed - e.g. run.gd hides the live view
    # (and its nested CanvasLayers) when the map is consulted over the top of it.
    if tooltip_owner is CanvasItem and not tooltip_owner.is_visible_in_tree():
        return false
    return true


var testing_mode: bool = false
var tutorial_on = false
var tutorial_reset_power_warning = true

var gold = 75
var player_hp = 66
var player_max_hp = 66


var roll_value: int = 0  # Stores the latest dice roll result
var last_roll: int = 0
var blue_dice_current_amount = 2
var blue_dice_max_amount = 2
var blue_dice_bonus_amount = 0
var blue_dice_bonus_amount_fight = 0
var red_dice_current_amount = 1
var red_dice_max_amount = 1
var red_dice_bonus_amount = 0
var evil_dice_current_amount = 0
var evil_dice_max_amount = 0
var evil_dice_bonus_amount = 0
var green_dice_current_amount = 0
var green_dice_max_amount = 0
var green_dice_bonus_amount = 0
var giant_dice_current_amount = 0
var giant_dice_max_amount = 0
var giant_dice_bonus_amount = 0
var magma_dice_current_amount = 0
var magma_dice_max_amount = 0
var magma_dice_bonus_amount = 0
var even_dice_current_amount = 0
var even_dice_max_amount = 0
var even_dice_bonus_amount = 0
var odd_dice_current_amount = 0
var odd_dice_max_amount = 0
var odd_dice_bonus_amount = 0
var mech_dice_current_amount = 0
var mech_dice_max_amount = 0
var mech_dice_bonus_amount = 0
var mech_dice_bonus_amount_fight = 0

var ink_active := false

var charged_dice_this_turn := false
var dice_amount_rolled_this_turn = 0
var dice_type = "blue"
var current_card = null
var charged_card_instance_id: int = 0
# Every card currently sitting in a Red socket, in socket order. The scalar above stays
# as socket 1 (a lot of code reads it); this is what the roll actually plays, so the
# Second Socket card works by appending rather than by rewriting the socket system.
var charged_card_instance_ids: Array[int] = []
var playing_red_card = false
var dragging_card = false
var fight_turn = 0
var fight_dice_rolled = 0
var cards_played_this_turn = 0
var enemy_last_move = ""
var player: Player
var next_roll_value = 0
var next_roll_modifier = 0
# -1 = "no guaranteed roll queued" - NOT 0, since 0 is the Evil dice's crack face and is a
# perfectly legal value to guarantee (Scout picking it, Unlucky forcing it). See dice.gd's
# roll_dice() for the consumer - it used to check `!= 0`, which silently ignored a guaranteed
# 0 and rolled normally instead.
var next_guaranteed_roll = -1
# What actually reached HP on the last hit (post-block since 2026-08-04, itch feedback:
# "attacked for 6 with 5 block should show 1"). The popup AND every stat/achievement hook
# in damage_effect.gd read this - one number, no display/stat divergence.
var damage_to_display = 0
# How much of the last hit the target's block soaked. Lets damage_effect.gd tell a fully
# BLOCKED hit (show "Blocked") apart from a hit that was 0 for other reasons (show "-0").
var blocked_to_display = 0
var final_enemy_damage = 0
var dice_inventory = ["blue", "red"]
var roll_history = []
# The dice TYPE of the most recent roll in the current chain. roll_history holds the values;
# this holds whose they were. Only ever read while roll_history is non-empty (the Flux gate in
# dice.gd), and any roll that makes it non-empty writes this first - so it needs no clearing of
# its own beyond the resets below.
var last_rolled_type: String = ""
var last_played_card_position: Vector2 = Vector2.ZERO  # global center of the most recently played card; used as the origin for the refuel "dice fly back" effect
var shop_initialized = false  # Whether the shop has been initialized
var shop_dice_selection = []  # Stores which dice are shown
# Column index (0-8, DICE_TYPE_ORDER space) of the discounted "deal die" sold in the CARD
# shop - always a type NOT among the 3 regular dice-shop picks, -1 = none (old saves /
# just bought). Re-picked when the dice shop rerolls and when a card shop opens with -1.
var shop_dice_deal_index = -1
# Card-removal services bought this run - the card shop's removal price escalates off this
# (50, 75, 100... like STS purges). Reset in reset_run_state(), saved/restored by run.gd.
var card_removals_bought = 0

# --- Dice-shop economics, shared between the dice shop (scenes/shop/shop.gd) and the
# card shop's discounted deal-die slot (scenes/shop/card_shop.gd). Moved here 2026-07-23
# so both shops always read the same numbers.
# Column order of the dice shop - shop_dice_selection / shop_dice_deal_index index space.
const DICE_TYPE_ORDER := ["evil", "giant", "magma", "even", "odd", "blue", "red", "green", "mech"]
const DICE_BASE_PRICES := {
    # Ordering is deliberate (2026-08-13 dice-variety pass): a first die of a NEW type must not
    # be undercut by another copy of a starter, so the discovery aisle (green..odd) sits below
    # blue/red, and only the genuinely stronger dice (evil/giant/magma) keep a premium over them.
    # Bases are tuned so die #1 is a first-shop commitment (~floor 5-7), not a floor-3 impulse
    # buy - total dice count is governed by the escalation below, not by these numbers.
    "evil": 185, "giant": 185, "magma": 220, "even": 165, "odd": 165,
    "blue": 170, "red": 170, "green": 115, "mech": 145,
}
# Every dice purchase (ANY type) raises ALL dice prices by this factor. Die #1 at base =
# the happy milestone; die #2 at ~1.5x = late-act-1 stretch; die #3 at ~2.25x = act-2 trophy.
const DICE_PRICE_ESCALATION := 1.5
const DICE_DEAL_DISCOUNT := 0.8  # the deal die sells at 80% of the current escalated price


func current_dice_price(type: String) -> int:
    var total_purchased := 0
    for count in purchased_dice_counts.values():
        total_purchased += count
    # Haggler's Loupe applies AFTER escalation, so the discount stays a flat percentage of
    # what the die actually costs right now rather than a shrinking one-off rebate.
    # Explicit float: DICE_BASE_PRICES[type] is a Dictionary subscript, so it is a Variant
    # and `:=` cannot infer from it - which makes the WHOLE of global.gd fail to parse, and
    # every script that touches Global fail with it. gdtoolkit does not catch this.
    var price: float = DICE_BASE_PRICES[type] * pow(DICE_PRICE_ESCALATION, float(total_purchased))
    return int(price * (1.0 - dice_price_discount))


# Re-derives cheapest_dice_price from the CURRENT selection + escalation. The dice-shop
# panel used to be the only writer, so any price change while it was closed (e.g. the
# card-shop deal die escalating all prices) left the map badge comparing gold against a
# stale snapshot. Anything that changes prices must end up here (via dice_price_changed).
func refresh_cheapest_dice_price() -> void:
    if shop_dice_selection.is_empty():
        cheapest_dice_price = null
        return
    var cheapest = null
    for index in shop_dice_selection:
        var price := current_dice_price(DICE_TYPE_ORDER[index])
        if cheapest == null or price < cheapest:
            cheapest = price
    cheapest_dice_price = cheapest


# First-visit init of the dice-shop state - called by BOTH shops, since either room can be
# the first one the player sees (the deal die needs the selection to exclude).
func ensure_dice_shop_state() -> void:
    if shop_initialized:
        return
    var chosen_indexes := []
    while chosen_indexes.size() < 3:
        var rand_index := randi() % DICE_TYPE_ORDER.size()
        if not chosen_indexes.has(rand_index):
            chosen_indexes.append(rand_index)
    shop_dice_selection = chosen_indexes
    shop_dice_deal_index = pick_dice_deal_index()
    refresh_cheapest_dice_price()
    shop_initialized = true


# Deal die is drawn from the 6 types NOT in the current dice-shop selection, so the card
# shop always offers something the dice shop doesn't have right now.
func pick_dice_deal_index() -> int:
    var candidates := []
    for i in DICE_TYPE_ORDER.size():
        if not shop_dice_selection.has(i):
            candidates.append(i)
    return candidates[randi() % candidates.size()]

var lose_strength_next_turn = 0
var has_blocked_last_turn = false

# Run-scoped counter for the "They see me rollin" achievement (20 Blue rolls in one run).
# Incremented by AchievementManager on Events.dice_rolled; saved/restored by run.gd.
var blue_dice_rolled_this_run = 0

# Run-lifetime stats shown on the end-of-run screens (Game Over panel + the boss GG
# panels), rendered by scenes/ui/run_stats_panel.gd. Incremented at the same choke
# points the achievements already use (dice.gd roll apply, damage_effect.gd,
# card.gd::play, enemy.gd death, run.gd floor label). Reset in reset_run_state(),
# saved/restored by run.gd ("run_screen_stats" key in the save dict).
var run_stat_dice_rolled := 0
var run_stat_power_generated := 0
var run_stat_biggest_hit := 0
var run_stat_damage_taken := 0
var run_stat_cards_played := 0
var run_stat_enemies_slain := 0
var run_stat_highest_floor := 1

# Relic-driven passive modifiers (set on initialize_relic, reset on deactivate_relic,
# same lifecycle as any other per-battle relic effect):
var scout_bonus_amount: int = 0  # Cartographer's Quill - extra Scout face shown, capped by the panel's 6 slots
var blessing_cast_any_roll: bool = false  # Prayer Beads - bypasses every Blessing card's roll-threshold gate

# One-shot flag consumed by battle_reward.gd::_show_card_rewards() - swaps each drawn
# card for its upgraded_version when available, then resets itself. Set by
# event_wandering_merchant.gd's browse option.
var force_upgraded_card_rewards: bool = false
var starting_power_next_turn = 0
var is_removing_card = true
var removing_card: bool = false
var upgrading_card: bool = false
var power_generated_this_turn = 0

var purchased_dice_counts = {
    "evil": 0,
    "giant": 0,
    "magma": 0,
    "even": 0,
    "odd": 0,
    "blue": 0,
    "red": 0,
    "green": 0,
    "mech": 0
}

var cheapest_dice_price

var sfx_click = preload("res://sfx/219069_annabloom_click1 (mp3cut.net).wav")
var sfx_gold_pickup = preload("res://gold_pickup_sound.mp3")

# Queue of rolls the tutorial forces, consumed front-to-back by dice.gd::roll_dice() -
# replaces the old single tutorial_forced_roll int (2026-07-12 redesign, see
# tutorial_redesign_2026-07.md). TutorialDirector pushes onto this before a gated ROLL
# step; dice.gd pops the front value and rolls it instead of the real random result.
var tutorial_forced_rolls: Array[int] = []

# Queue of face values the tutorial forces into the Scout preview, consumed by
# battle.gd::_on_scout_effect() instead of its random pick. Same "pop as consumed"
# convention as tutorial_forced_rolls.
var tutorial_forced_scout_faces: Array[int] = []

var tutorial_fight = true
# NOT tutorial-exclusive despite the name - crab_enemy_ai.tscn's TutorialAttack node
# (weight 10, used by every real Crab fight in the game, all 3 tiers) gates on this
# flag too, as a one-shot "opening move" for the FIRST Crab fight of the whole run.
# Do not repurpose or rename without also touching enemies/crab/tutorial_attack.gd.
var tutorial_enemy_attack = true
var tutorial_bonus_requirement_explanation_needed = true
var tutorial_transcendent_explanation_needed = true
var tutorial_dice_shop_explanation_needed = false
var tutorial_blessing_explanation_needed = true

var is_final_boss_fight = false
var game_over_state = false

# Set when the debug BattleButton (run.gd) drops straight into a fresh battle for
# testing - lets battle_over_panel.gd skip its post-win auto-advance delay so a
# debug battle can be iterated on quickly. Reset immediately after being read so it
# never leaks into a real map-flow battle started right after.
var debug_battle_entry := false

# Which act the run is currently in (1 or 2). Reset by run.gd::_start_run(), flipped
# to 2 by run.gd::_enter_act_2() after the act-1 boss. Battle scaling (battle.gd) and
# battle-pool selection (run.gd) both read this.
var current_act := 1

# Act-2 dice infusions: dice type -> infusion id (e.g. {"blue": "arcane"}). Set by the
# post-act-1-boss infusion screen (scenes/dice_infusion/), permanent for the rest of the
# run, saved/restored by run.gd. Designs live in custom_resources/dice_infusions.gd.
var dice_infusions := {}

# Transient: true ONLY while a Berserker-infused socketed card's apply_effects() is
# running (scoped tightly in card.gd::play()) - damage_effect.gd reads it to apply the
# +50% damage. Never true outside that synchronous window.
var berserker_boost_active := false

# The Sprite2D texture battle.gd picked for the fight just finished (see
# Battle._select_background_texture()) - battle_reward.gd mirrors it on the reward
# screen so the background matches the biome you were just fighting in, instead of
# always showing the same static placeholder. Null before any battle has happened
# yet this run (e.g. a Treasure room reward on floor 1), in which case battle_reward
# keeps its .tscn-authored default.
var last_battle_background: Texture2D = null


func is_dice_infused(dice_type: String) -> bool:
    return dice_infusions.has(dice_type)

var no_reset: bool = false

# Trebuchet (Blessing): flat bonus added to every thrown die's landing damage for the
# rest of the FIGHT. Reset by battle.gd::start_battle() alongside ink_active, and in
# reset_run_state() for run hygiene.
var thrown_dice_bonus_fight := 0

# LOADED: a flat Power bonus added to EVERY roll, unlike Boost (next_roll_modifier) which is
# consumed by one roll. The status badge is display only - the effect has to live here because
# dice.gd reads it inside _apply_roll_result (same split as Emanation's fight-scoped global).
# Fight-scoped: reset by battle.gd::start_battle() alongside ink_active AND in reset_run_state().
# Distinct dice TYPES rolled this turn, used as a set (the value is always true). Drives the
# rainbow archetype - Spectrum reads its size, the Prismatic Lens relic fires at 4. Turn-scoped:
# cleared by player_handler.gd::start_turn next to dice_amount_rolled_this_turn.
var dice_types_rolled_this_turn := {}
# Natural 6s rolled this FIGHT (the rolled face itself, never a Boosted/Loaded 5->6). Drives
# Jackpot and Effigy. Fight-scoped: reset by battle.gd::start_battle alongside ink_active.
var sixes_rolled_this_fight := 0

# Fight-scoped face-set edits from CARDS (Red trim, Counterfeit), keyed by dice type. Layered
# ON TOP of a dice infusion's own override, and computed at play time from whatever the die's
# faces are right then - so "remove the 2 lowest faces" trims the effective set, not the
# printed one. Read by dice.gd (the roll), battle.gd (the Scout preview) and
# Card.thrown_faces_for (thrown dice); all three must stay in step or the preview lies.
var face_overrides := {}
# Kaleidoscope: for THIS TURN only, switching dice type does not wipe the Power chain.
var keep_power_on_type_change := false
# Reservoir: how much Power survives a card's reset (0 = the normal full wipe).
var power_kept_on_reset := 0
# Socketless Red blessing: the Red die may be rolled with an empty socket, hitting everything.
var socketless_red := false
# Socketless Red+ only: Strength granted by EACH empty-socket Red roll (0 = base card).
var socketless_red_strength := 0
# "Keep your Dice": set when the card ends the turn, consumed by dice_interface's turn-end
# capture, which stashes every type's leftovers in kept_dice for the next refill to add back.
var keep_all_dice_next_turn := false
var kept_dice := {}

# IN-HAND PASSIVES: cards that do something while they SIT IN YOUR HAND. Read live off the
# Hand's children rather than mirrored into a set here - a mirror desyncs the moment a card
# leaves by a path nobody remembered (played, dragged, swept to discard), and every one of
# those paths reparents the CardUI out of the Hand, so the node tree is already the truth.
const IN_HAND_RED_AURA := "card_blood_oath"
const IN_HAND_RED_AURA_PLUS := "card_blood_oath_plus"
const IN_HAND_TALISMAN := "card_talisman"
const IN_HAND_TALISMAN_PLUS := "card_talisman_plus"
const IN_HAND_DEAD_WEIGHT := "card_dead_weight"
const IN_HAND_DEAD_WEIGHT_PLUS := "card_dead_weight_plus"

# Talisman, held: every NATURAL 6 you roll grants this much Block. Read by dice.gd at the
# same `last_roll == 6` check Jackpot and Effigy already key off, so all three agree on what
# a "6" is (a rolled face, never a Boosted or Loaded 5->6).
const TALISMAN_SIX_BLOCK := 3
const TALISMAN_PLUS_SIX_BLOCK := 5

# Dice types granted Ricochet's reroll by a card. "odd" (Ricochet) is native and always
# allowed; this is the graft list on top of it.
var reroll_types := {}

# Red socket capacity. 1 normally; the Second Socket card raises it, and ONE red roll then
# plays every socketed card in order.
var red_socket_capacity := 1

var loaded_amount := 0
# The slice of loaded_amount that expires at the start of the next turn ("Loaded N this turn").
# LoadedStatus.apply_status() subtracts it and zeroes this - see statuses/loaded.gd.
var loaded_expiring := 0

# Golem Dice (internal type "even"): unspent dice roll over into the next turn instead of
# being lost. Captured from the leftover count on player_turn_ended and consumed by
# dice_interface's refill on the next player_turn_started.
#
# ⚠️ This CANNOT just read even_dice_current_amount at refill time, which is what the other
# eight types effectively do. Buying a Golem die in the shop does `current += 1` BETWEEN
# fights (shop.gd), so the refill would read that purchase as "carried over" and hand out
# the die twice. Fight-scoped for the same reason ink_active is: leftovers must not survive
# into the next combat. Reset by battle.gd::start_battle() and reset_run_state().
var golem_dice_carryover := 0

# True only while a Ricochet reroll is travelling through dice.gd's roll path. Read by
# dice_interface._on_dice_rolled to skip the die decrement: a reroll re-rolls the die you
# already spent, it must not spend a second one. Everything ELSE on that path is deliberately
# left alone - relics, per-roll counters and the Bulwark infusion all treat the reroll as a
# second roll (Julien's call, 2026-08-12); only Power, roll history and the shown face are
# rewound, because those are the only ones that can be undone without a rewind system for
# damage already dealt and Block already granted.
var ricochet_reroll_active := false

# --- Relic-owned switches (2026-08-23 relic batch) ------------------------------------
# All of these are written by a relic's initialize_relic() and cleared by its
# deactivate_relic(). Relics are initialised ONCE when added and only deactivated when the
# relic itself leaves the RelicHandler (which lives in run.tscn, so it survives every scene
# change), which is why a shop-facing one like the price discount can be read outside combat.
# They are still reset below so a NEW run in the same session cannot inherit a stale value.

# Worm's Eye Lens: flat damage added to cards whose requirement is Max. Applied inside
# ModifierHandler.get_modified_value so the real damage AND the dynamic description both
# pick it up, exactly like Dead Weight+'s in-hand bonus.
var max_card_damage_bonus := 0
# The requirement of the card currently resolving, or -1 outside a play. Scoped around
# apply_effects() by Card.play() - same trick as berserker_boost_active, so damage from
# anything OTHER than the card itself (a relic reacting to the same roll) stays out.
var playing_card_requirement := -1
# Blood Chalice: what the resolving card was aimed at. Captured by Card.play() because
# Events.card_played only carries the Card, and "apply Exposed to the enemy you just hit"
# needs the target - falling back to "all enemies" would quietly be a much stronger relic.
var last_played_card_targets: Array[Node] = []
# Marked Deck: armed at the start of each fight, consumed by the first RED roll (dice.gd).
var marked_deck_armed := false
# Mortar Trowel: Block kept when the turn rolls over (0 = vanilla "block resets to 0").
var block_carryover_cap := 0
# Haggler's Loupe: fraction taken off every dice price, applied in current_dice_price().
var dice_price_discount := 0.0
# Golem Heart: makes the "keep your dice" stash permanent instead of a one-shot.
var keep_all_dice_always := false
# Wayfinder Compass / Diplomat's Seal: Power the player was holding when they last switched
# dice type. Captured by dice_interface BEFORE it emits active_dice_changed, because the
# handler that zeroes the bank also listens to that signal - reading roll_value from inside
# a listener would be a race decided by connection order.
var power_at_last_switch := 0
# Thorned Plate: the enemy currently taking its turn (enemy.gd::do_turn), so a reflected hit
# can find who threw the punch. Null outside the enemy turn.
var acting_enemy: Node = null

var pending_card_rewards = 1
var hound_debuff_attack_done = false
var gargantua_debuff_attack_done = false
var has_rolled_6_this_turn = false
var has_rolled_1_this_fight = false

# Set by the main menu's Load Run button; consumed (and cleared) by run.gd::_late_init,
# which then restores from SaveManager instead of starting fresh.
var load_run_requested := false


# Puts every RUN-scOPED field back to its new-run default. Called by run.gd::_late_init on
# every run start (fresh or loaded - a load overwrites on top of this clean slate).
# Fixes a latent bug at the same time: the death-screen Restart button reloads the Run scene,
# but this autoload survives scene reloads - before this function existed, gold/dice/act/
# tutorial flags from the dead run silently carried over into the "fresh" one.
# NOT reset here: testing_mode (dev switch), tutorial_on (set by the main menu before the
# scene loads), load_run_requested (the flag that decides fresh-vs-load), player (node ref,
# reassigned by the battle scene), and the preloaded sfx.
# First dice type the player actually owns, in the combat interface's slot order - the
# fallback "active die" used at battle start / battle end instead of a hard-coded "blue"
# (run loadouts from dice_loadout.gd can start a run with no Blue at all). Red is
# deliberately LAST: it rolls after the card is picked (the gamble die), so a fight
# should never open on it while any planning die exists.
func default_active_dice_type() -> String:
    for type in ["blue", "evil", "giant", "magma", "even", "odd", "green", "mech", "red"]:
        if get(type + "_dice_max_amount") > 0:
            return type
    return "blue"


func reset_run_state() -> void:
    gold = 75
    player_hp = 66
    player_max_hp = 66

    blue_dice_current_amount = 2
    blue_dice_max_amount = 2
    blue_dice_bonus_amount = 0
    blue_dice_bonus_amount_fight = 0
    red_dice_current_amount = 1
    red_dice_max_amount = 1
    red_dice_bonus_amount = 0
    for type in ["evil", "green", "giant", "magma", "even", "odd", "mech"]:
        set(type + "_dice_current_amount", 0)
        set(type + "_dice_max_amount", 0)
        set(type + "_dice_bonus_amount", 0)
    mech_dice_bonus_amount_fight = 0

    roll_value = 0
    last_roll = 0
    roll_history = []
    last_rolled_type = ""
    next_roll_value = 0
    next_roll_modifier = 0
    next_guaranteed_roll = -1
    starting_power_next_turn = 0
    power_generated_this_turn = 0
    no_reset = false
    thrown_dice_bonus_fight = 0
    loaded_amount = 0
    loaded_expiring = 0
    dice_types_rolled_this_turn = {}
    sixes_rolled_this_fight = 0
    face_overrides = {}
    keep_power_on_type_change = false
    reroll_types = {}
    red_socket_capacity = 1
    power_kept_on_reset = 0
    socketless_red = false
    socketless_red_strength = 0
    keep_all_dice_next_turn = false
    kept_dice = {}
    golem_dice_carryover = 0

    # Relic-owned switches: cleared here so a fresh run never inherits the previous run's
    # relics. Each is re-established by its relic's initialize_relic() as it is re-added.
    max_card_damage_bonus = 0
    playing_card_requirement = -1
    last_played_card_targets = []
    marked_deck_armed = false
    block_carryover_cap = 0
    dice_price_discount = 0.0
    keep_all_dice_always = false
    power_at_last_switch = 0
    acting_enemy = null

    ink_active = false
    charged_dice_this_turn = false
    dice_amount_rolled_this_turn = 0
    dice_type = "blue"
    current_card = null
    charged_card_instance_id = 0
    charged_card_instance_ids = []
    playing_red_card = false
    dragging_card = false
    fight_turn = 0
    fight_dice_rolled = 0
    cards_played_this_turn = 0
    enemy_last_move = ""
    lose_strength_next_turn = 0
    has_blocked_last_turn = false
    blue_dice_rolled_this_run = 0
    run_stat_dice_rolled = 0
    run_stat_power_generated = 0
    run_stat_biggest_hit = 0
    run_stat_damage_taken = 0
    run_stat_cards_played = 0
    run_stat_enemies_slain = 0
    run_stat_highest_floor = 1
    has_rolled_6_this_turn = false
    has_rolled_1_this_fight = false
    hound_debuff_attack_done = false
    gargantua_debuff_attack_done = false

    dice_inventory = ["blue", "red"]
    purchased_dice_counts = {
        "evil": 0, "giant": 0, "magma": 0, "even": 0, "odd": 0,
        "blue": 0, "red": 0, "green": 0, "mech": 0,
    }
    cheapest_dice_price = null
    shop_initialized = false
    shop_dice_selection = []
    shop_dice_deal_index = -1
    card_removals_bought = 0

    removing_card = false
    upgrading_card = false
    current_act = 1
    dice_infusions = {}
    last_battle_background = null
    berserker_boost_active = false
    is_final_boss_fight = false
    game_over_state = false
    pending_card_rewards = 1

    tutorial_reset_power_warning = true
    tutorial_forced_rolls = []
    tutorial_forced_scout_faces = []
    tutorial_fight = true
    tutorial_enemy_attack = true
    tutorial_bonus_requirement_explanation_needed = true
    tutorial_transcendent_explanation_needed = true
    tutorial_dice_shop_explanation_needed = false
    tutorial_blessing_explanation_needed = true
