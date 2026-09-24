extends RefCounted

# CAPTURE RIG - one key sets up the Reddit gameplay take (Julien, 2026-09-23).
#
# Press F12 in a DEBUG build (an F5 run from the editor) on the main menu, or at any moment
# during a take, and the game jumps straight into the staged fight below with a mid-run
# looking deck, dice, relics, gold, HP and floor, the take's five cards in the opening hand,
# and the debug button column and the Discord pin hidden. F12 again restarts the take, so
# ten takes cost ten key presses instead of ten trips through the menu.
#
# What it never does: write or delete the run save (SaveManager checks `active`), unlock an
# achievement or add to a lifetime stat (AchievementManager checks it too), or count as a
# started run for the dice loadout picker. A take cannot touch Julien's real profile.
#
# Release exports: F12 is only read when OS.is_debug_build(), so this file ships but is
# inert. It has to ship - dice.gd, run.gd and the others preload it - which is also why it
# is NOT named debug_*: the Web preset excludes res://debug_*, and a preload of an excluded
# file would break the export.
#
# Deliberately free of any autoload reference (Global, Events, Curtain...). It is preloaded
# by the AchievementManager autoload, and a preload chain that needs an autoload's script
# while autoloads are still booting fails with an unrelated-looking resource error (see
# memory feedback_gdscript_preload_time_autoload_race). Data and static state only; the code
# that APPLIES the rig lives in run.gd, which runs long after boot.
#
# ---------------------------------------------------------------------------------------
# THE TAKE (about 30 seconds, one turn). Blue rolls are scripted, so beats 1-2 land the same
# every time; beats 3-4 are pinned by the Scout faces and Lucky, which are real mechanics.
#
#  1. Blue is active. ROLL -> 4, ROLL -> 1 (the dud). Power 5, looks bad.
#     Play Recombobulate: both dice fly back, Power resets.
#     ROLL -> 5, ROLL -> 6 (max roll, crush burst), ROLL -> 4. Power 15.
#  2. Strike a Kraken for 15. It drops to 6 HP.
#  3. Click the Mech die. Play Scout 3: the panel shows 5 / 2 / 6. Pick the 2.
#     ROLL -> 2. Optional: press the Mech down arrow for a 1.
#     Play Catapult (Max 2): 6 to ALL enemies. The wounded Kraken dies. You gain Lucky,
#     and gold glints start twinkling on the die until the Red roll spends it.
#  4. Click the Red die. Drag Flurry into its socket. ROLL -> Lucky makes it a 6,
#     Blood Sword adds 2 = 8. Aim at the Marauder: two hits of 8.
#  5. Nothing left to do, so End Turn pulses gold. Click it and cut on the enemy turn.
#
# The math assumes the live numbers on 2026-09-23: Marauder 36 HP, Bigger Kraken 21 HP
# (tier-2 files). run.gd prints the enemy HP at the start of every take so a later retune
# shows up in the log instead of as a Kraken that survives beat 3.
# ---------------------------------------------------------------------------------------

const HOTKEY := KEY_F12

# True from the F12 press until the main menu loads again (main_menu.gd clears it), so a
# normal New Run started after a capture session is never mistaken for a take.
static var active := false

# Marauder + two Bigger Krakens. Tier 2 = floors 9-13 in act 1, matching FLOOR below.
const FIGHT := "res://battles/tier_2_machopeur_octopus.tres"
const FIGHT_TIER := 2

# Top-bar dressing so the frame reads as the middle of a run, not a fresh one.
const FLOOR := 11
const GOLD := 142
const HEALTH := 52

const DICE := {"blue": 2, "red": 1, "mech": 1}

# The starter deck plus the two cards the take needs and two filler drafts. 16 cards is a
# plausible floor-11 deck; only OPENING_HAND is ever seen, the rest just sets the counters.
const DECK := [
    "res://characters/warrior/cards/warrior_axe_attack1.tres",
    "res://characters/warrior/cards/warrior_axe_attack2.tres",
    "res://characters/warrior/cards/warrior_axe_attack3.tres",
    "res://characters/warrior/cards/warrior_axe_attack4.tres",
    "res://characters/warrior/cards/warrior_block1.tres",
    "res://characters/warrior/cards/warrior_block2.tres",
    "res://characters/warrior/cards/warrior_block3.tres",
    "res://characters/warrior/cards/warrior_block4.tres",
    "res://characters/warrior/cards/low_blow.tres",
    "res://characters/warrior/cards/reinforce.tres",
    "res://characters/warrior/cards/card_recombobulate.tres",
    "res://characters/warrior/cards/card_scout3_no_exhaust.tres",
    "res://characters/warrior/cards/card_catapult.tres",
    "res://characters/warrior/cards/card_flurry.tres",
    "res://characters/warrior/cards/bullseye.tres",
    "res://characters/warrior/cards/card_meteor.tres",
]

# Dealt left to right in this order, which is roughly the order they are played.
const OPENING_HAND := [
    "res://characters/warrior/cards/card_recombobulate.tres",
    "res://characters/warrior/cards/warrior_axe_attack1.tres",
    "res://characters/warrior/cards/card_scout3_no_exhaust.tres",
    "res://characters/warrior/cards/card_catapult.tres",
    "res://characters/warrior/cards/card_flurry.tres",
]

# Added after the starting relic (Dice Bag). Blood Sword is part of beat 4. The other two
# are dressing with no effect in this fight: Haggler's Loupe only discounts the dice shop,
# and Alms Box only fires on a Blessing, which this deck has none of.
const EXTRA_RELICS := [
    "res://relics/blood_sword.tres",
    "res://relics/hagglers_loupe.tres",
    "res://relics/alms_box.tres",
]

# Blue faces in the order the Blue die lands. Only Blue consumes this, so the Scouted Mech
# roll and the Lucky Red roll are left to their own mechanics. Once it runs out, Blue rolls
# are random again (a take that goes off-script degrades to normal play, not to errors).
const BLUE_ROLLS := [4, 1, 5, 6, 4]
# The first Scout of the take shows these faces (consumed by battle.gd once).
const SCOUT_FACES := [5, 2, 6]

static var _blue_queue: Array = []


# Called on the F12 press, before the scene change.
static func begin() -> void:
    active = true
    _blue_queue = BLUE_ROLLS.duplicate()


static func end() -> void:
    active = false
    _blue_queue = []


# dice.gd asks this on every roll. -1 = no scripted face, roll normally.
static func pop_forced_roll(dice_type: String) -> int:
    if not active or dice_type != "blue" or _blue_queue.is_empty():
        return -1
    return int(_blue_queue.pop_front())
