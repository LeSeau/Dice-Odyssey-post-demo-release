extends Node

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
var next_guaranteed_roll = 0
var damage_to_display = 0
var final_enemy_damage = 0
var dice_inventory = ["blue", "red"]
var roll_history = []
var last_played_card_position: Vector2 = Vector2.ZERO  # global center of the most recently played card; used as the origin for the refuel "dice fly back" effect
var shop_initialized = false  # Whether the shop has been initialized
var shop_dice_selection = []  # Stores which dice are shown

var lose_strength_next_turn = 0
var has_blocked_last_turn = false
var starting_power_next_turn = 0
var is_removing_card = true
var removing_card: bool = false
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
var tutorial_forced_roll = 0

var tutorial_block = true
var tutorial_low_blow = false
var tutorial_fight = true
var tutorial_enemy_attack = true
var tutorial_red_dice = false
var tutorial_charging_card = false
var tutorial_red_attack = false
var tutorial_end_turn = false
var tutorial_blue_dice = false
var tutorial_second_turn = false
var tutorial_recombobulate = false
var tutorial_bonus_requirement_explanation_needed = true
var tutorial_transcendent_explanation_needed = true
var tutorial_dice_shop_explanation_needed = false
var tutorial_blessing_explanation_needed = true

var is_final_boss_fight = false
var game_over_state = false

var no_reset: bool = false

var pending_card_rewards = 1
var hound_debuff_attack_done = false
var gargantua_debuff_attack_done = false
var has_rolled_6_this_turn = false
var has_rolled_1_this_fight = false
