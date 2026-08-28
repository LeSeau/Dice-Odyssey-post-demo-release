class_name RunStats
extends Resource



const STARTING_GOLD := 25
const STARTING_HP := 66
const BASE_CARD_REWARDS := 3

# ---- Card-reward rarity pity (STS2 model) --------------------------------------------
# The odds tables and the roll itself live in CardRarityDraw - read its header first. All
# that is persisted per run is this one offset, ported from STS2's AbstractOdds.CurrentValue
# (Core/Odds/CardRarityOdds.cs):
#
#   floor  -0.05  starting value, and where a Rare snaps it back to. Negative on purpose:
#                 normal rare odds are 0.03, so 0.03 + (-0.05) is under water and the first
#                 few cards of a run CANNOT be Rare. Replaces the old RUN_START_RARE_WEIGHT
#                 "no jackpot on floor 1" special case, which this subsumes exactly.
#   growth +0.01  added per non-rare card rolled for an encounter reward. Per CARD, not per
#                 screen - see CardRarityDraw's header for why that distinction is the
#                 whole ballgame.
#   cap    +0.40  ceiling, so normal rare odds top out at 43% after a long dry spell.
#
# Shop slots READ this value but never advance it (CardFactory.CreateForMerchant uses
# RollWithoutChangingFutureOdds), so browsing a shop can't starve the next combat reward.
const RARE_OFFSET_FLOOR := -0.05
const RARE_OFFSET_GROWTH := 0.01
const RARE_OFFSET_CAP := 0.4

@export var gold := STARTING_GOLD : set = set_gold
@export var hp := STARTING_HP : set = set_hp
@export var card_rewards := BASE_CARD_REWARDS
@export var rare_offset := RARE_OFFSET_FLOOR


func set_gold(new_amount: int) -> void:
    gold = new_amount
    Global.gold = gold
    Events.gold_changed.emit()


func set_hp(new_amount: int) -> void:
    hp = new_amount
    Global.hp = hp
    Events.hp_changed.emit()

# Dead today (nothing calls it - a fresh run gets a fresh RunStats.new()), kept as the
# honest single place to say "put rarity pity back to its run-start value" if a future
# system ever needs to.
func reset_rarity_odds() -> void:
    rare_offset = RARE_OFFSET_FLOOR
