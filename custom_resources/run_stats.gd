class_name RunStats
extends Resource



const STARTING_GOLD := 25
const STARTING_HP := 66
const BASE_CARD_REWARDS := 3
const BASE_NORMAL_WEIGHT := 8.0
const BASE_SUPPORT_WEIGHT := 2.0

@export var gold := STARTING_GOLD : set = set_gold
@export var hp := STARTING_HP : set = set_hp
@export var card_rewards := BASE_CARD_REWARDS
@export_range(0.0, 10.0) var normal_weight := BASE_NORMAL_WEIGHT
@export_range(0.0, 10.0) var support_weight := BASE_SUPPORT_WEIGHT


func set_gold(new_amount: int) -> void:
    gold = new_amount 
    Global.gold = gold
    Events.gold_changed.emit()
    

func set_hp(new_amount: int) -> void:
    hp = new_amount 
    Global.hp = hp
    Events.hp_changed.emit()

func reset_weights() -> void:
    normal_weight = BASE_NORMAL_WEIGHT
    support_weight = BASE_SUPPORT_WEIGHT
