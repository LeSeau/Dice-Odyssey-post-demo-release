class_name RunStats
extends Resource



const STARTING_GOLD := 25
const STARTING_HP := 66
const BASE_CARD_REWARDS := 3

# Card-reward rarity draw weights (see battle_reward.gd::_setup_card_chances/_update_rare_pity).
# Base split 6.0/3.7/0.3 = 60% / 37% / 3% per slot - Slay the Spire's normal-fight odds,
# explicitly requested by Julien after the first tuning (0.5 base + per-SLOT pity) flooded
# runs with uncommons/rares. Pity ticks once per reward SCREEN without a rare (+0.2, cap 2.0
# = ~17% per slot after ~8 dry screens), resets to base when a screen offers a rare. Only
# rare_weight ever moves at runtime - common/uncommon stay at their base value all game.
const BASE_COMMON_WEIGHT := 6.0
const BASE_UNCOMMON_WEIGHT := 3.7
const BASE_RARE_WEIGHT := 0.3
const RARE_WEIGHT_PITY_STEP := 0.2
const RARE_WEIGHT_PITY_CAP := 2.0

# "No jackpot on floor 1" (2026-08-15, STS2 audit 3.1). A run STARTS with rare weight at
# zero, so the very first card reward cannot be Rare; the existing dry-screen pity then
# lifts it (clamped up to BASE_RARE_WEIGHT) so every screen from the second on rolls at
# normal odds. This is the reference's negative-starting-offset rule translated to our
# granularity - theirs takes ~3 card rolls to reach possible-at-all, and we draw exactly
# 3 cards per screen.
#
# Why it matters more for us than for them: our Rare pool is 5 cards and several are
# run-defining, so a turn-3 Rare doesn't just spike power, it decides the build before
# the player has learned anything about the run. Costs no new saved state - it rides the
# rare_weight that is already persisted.
const RUN_START_RARE_WEIGHT := 0.0

@export var gold := STARTING_GOLD : set = set_gold
@export var hp := STARTING_HP : set = set_hp
@export var card_rewards := BASE_CARD_REWARDS
@export_range(0.0, 10.0) var common_weight := BASE_COMMON_WEIGHT
@export_range(0.0, 10.0) var uncommon_weight := BASE_UNCOMMON_WEIGHT
@export_range(0.0, 10.0) var rare_weight := RUN_START_RARE_WEIGHT


func set_gold(new_amount: int) -> void:
    gold = new_amount
    Global.gold = gold
    Events.gold_changed.emit()


func set_hp(new_amount: int) -> void:
    hp = new_amount
    Global.hp = hp
    Events.hp_changed.emit()

func reset_weights() -> void:
    common_weight = BASE_COMMON_WEIGHT
    uncommon_weight = BASE_UNCOMMON_WEIGHT
    # Back to the run-START value, not the base - a fresh run gets the no-rare-on-the-
    # first-screen guard again (see RUN_START_RARE_WEIGHT).
    rare_weight = RUN_START_RARE_WEIGHT
