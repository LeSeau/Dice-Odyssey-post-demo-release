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

@export var gold := STARTING_GOLD : set = set_gold
@export var hp := STARTING_HP : set = set_hp
@export var card_rewards := BASE_CARD_REWARDS
@export_range(0.0, 10.0) var common_weight := BASE_COMMON_WEIGHT
@export_range(0.0, 10.0) var uncommon_weight := BASE_UNCOMMON_WEIGHT
@export_range(0.0, 10.0) var rare_weight := BASE_RARE_WEIGHT


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
    rare_weight = BASE_RARE_WEIGHT
