extends Node


# App-scoped player settings (volumes, fullscreen) - loaded once at startup and
# applied to the audio buses/window here; the pause menu updates them live afterwards
# through SettingsManager. Deliberately NOT part of reset_run_state()/the run save:
# these belong to the player, not to a run.
func _ready() -> void:
    SettingsManager.load_and_apply()


var testing_mode: bool = false
var tutorial_on = false
var tutorial_reset_power_warning = true

var gold = 7575
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
var dice_amount_rolled_this_turn
var dice_type = "blue"
var current_card = null
var charged_card_instance_id: int = 0
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
var damage_to_display = 0
var final_enemy_damage = 0
var dice_inventory = ["blue", "red"]
var roll_history = []
var last_played_card_position: Vector2 = Vector2.ZERO  # global center of the most recently played card; used as the origin for the refuel "dice fly back" effect
var shop_initialized = false  # Whether the shop has been initialized
var shop_dice_selection = []  # Stores which dice are shown

var lose_strength_next_turn = 0
var has_blocked_last_turn = false

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


func is_dice_infused(dice_type: String) -> bool:
    return dice_infusions.has(dice_type)

var no_reset: bool = false

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
    next_roll_value = 0
    next_roll_modifier = 0
    next_guaranteed_roll = -1
    starting_power_next_turn = 0
    power_generated_this_turn = 0
    no_reset = false

    ink_active = false
    charged_dice_this_turn = false
    dice_amount_rolled_this_turn = 0
    dice_type = "blue"
    current_card = null
    charged_card_instance_id = 0
    playing_red_card = false
    dragging_card = false
    fight_turn = 0
    fight_dice_rolled = 0
    cards_played_this_turn = 0
    enemy_last_move = ""
    lose_strength_next_turn = 0
    has_blocked_last_turn = false
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

    removing_card = false
    upgrading_card = false
    current_act = 1
    dice_infusions = {}
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
