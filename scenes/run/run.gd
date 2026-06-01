class_name Run
extends Node

const BATTLE_SCENE := preload ("res://scenes/battle/battle.tscn")
const BATTLE_REWARD_SCENE := preload ("res://scenes/battle_reward/battle_reward.tscn")
const BOSS_SCENE := preload ("res://scenes/battle/battle.tscn")
const TREASURE_SCENE := preload ("res://scenes/treasure/treasure.tscn")
const CAMPFIRE_SCENE := preload ("res://scenes/campfire/campfire.tscn")
const EVENT_SCENE := preload("res://scenes/events/event_add_new_card.tscn")
const DICE_SHOP_SCENE = preload("res://scenes/shop/dice_shop.tscn")

const SHOP_SCENE := preload ("res://scenes/shop/card_shop.tscn")

@onready var current_view: Node = $CurrentView
@onready var map_button: Button = %MapButton
@onready var battle_button: Button = %BattleButton
@onready var shop_button: Button = %ShopButton
@onready var rewards_button: Button = %RewardsButton
@onready var deck_button: CardPileOpener = %DeckButton
@onready var deck_view: CardPileView = %DeckView
@onready var gold_ui: GoldUI = %GoldUI
@onready var relic_handler: RelicHandler = %RelicHandler

@onready var health_label: Label = $TopBar/BarItems/HBoxContainer/HealthLabel


@onready var map: Map = $Map
@onready var dice_shop: TextureButton = $TopBar/BarItems/DiceShop
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var blue_dice: VBoxContainer = $TopBar/BarItems/DiceTopBar/BlueDice
@onready var red_dice: VBoxContainer = $TopBar/BarItems/DiceTopBar/RedDice
@onready var blue_dice_texture: TextureRect = $TopBar/BarItems/DiceTopBar/BlueDice/BlueDiceTexture
@onready var blue_dice_amount: Label = $TopBar/BarItems/DiceTopBar/BlueDice/BlueDiceAmount
@onready var red_dice_amount: Label = $TopBar/BarItems/DiceTopBar/RedDice/RedDiceAmount

@onready var dice_top_bar: HBoxContainer = $TopBar/BarItems/DiceTopBar

@onready var map_music: AudioStreamPlayer2D = $MapMusic

@onready var affordable_indicator: Label = $TopBar/BarItems/DiceShop/AffordableIndicator
@onready var dice_shop_explanation_box: Panel = $TopBar/DiceShopExplanationBox


@export var event_stats_pool: EventStatsPool
@export var battle_stats_pool: BattleStatsPool 
@export var elite_relic_pool: RelicPool

var stats: RunStats
var character: CharacterStats
var dice_displays = {}
var used_battles: Array[BattleStats] = []  # Track used battles during this run

var sfx_click = preload("res://sfx/219069__annabloom__click1.wav")

func _ready() -> void:
    call_deferred("_late_init")


func _late_init() -> void:
    var warrior = load("res://characters/warrior/warrior.tres")
    character = warrior.create_instance()

    Events.show_reward.connect(_on_show_reward)
    Events.show_reward_with_relic.connect(_on_show_reward_with_relic)
    Events.update_dice_top_bar.connect(_on_update_dice_top_bar)
    Events.hp_changed.connect(_on_hp_changed)
    Events.card_removed.connect(_on_card_removed)
    Events.open_deck_view.connect(_on_open_deck_view)
    Events.show_map_requested.connect(_on_show_map_requested)
    Events.stop_map_music.connect(_on_stop_map_music)
    Events.start_map_music.connect(_on_start_map_music)
    Events.check_if_can_purchase_dice.connect(_on_check_if_can_purchase_dice)

    _start_run()
    _on_update_dice_top_bar()
    map_music.play()


    
# Initialize dice display containers
func _initialize_dice_display() -> void:
    # Store the existing blue and red dice displays
    dice_displays["blue"] = blue_dice
    dice_displays["red"] = red_dice
    
    # Create templates for other dice types that can be added later
    var dice_types = ["evil", "giant", "magma", "even", "odd", "green", "mech"]
    
    for dice_type in dice_types:
        # Skip if we've already created this dice type
        if dice_displays.has(dice_type):
            continue
            
        # Check if the player has this dice type
        var max_amount = get_dice_max_amount(dice_type)
        if max_amount <= 0:
            continue
            
        # Create the dice display container
        var new_dice = blue_dice.duplicate()
        var texture_rect = new_dice.get_node("BlueDiceTexture")
        var amount_label = new_dice.get_node("BlueDiceAmount")
        
        # Rename nodes
        new_dice.name = dice_type.capitalize() + "Dice"
        texture_rect.name = dice_type.capitalize() + "DiceTexture"
        amount_label.name = dice_type.capitalize() + "DiceAmount"
        
        # Update texture
        texture_rect.texture = load("res://assets/images/" + dice_type + "6.png")
        
        # Add to scene and store reference
        dice_top_bar.add_child(new_dice)
        dice_displays[dice_type] = new_dice
        
        # Adjust position
        new_dice.show()

# Helper function to get dice max amount from Global
func get_dice_max_amount(dice_type: String) -> int:
    match dice_type:
        "blue": return Global.blue_dice_max_amount
        "red": return Global.red_dice_max_amount
        "evil": return Global.evil_dice_max_amount
        "giant": return Global.giant_dice_max_amount
        "magma": return Global.magma_dice_max_amount
        "even": return Global.even_dice_max_amount
        "odd": return Global.odd_dice_max_amount
        "green": return Global.green_dice_max_amount
        "mech": return Global.mech_dice_max_amount
        _: return 0

# Updated function to handle all dice types
func _on_update_dice_top_bar() -> void:
    print("updating dice top bar")
    
    # Always update blue and red dice (starting dice)
    blue_dice_amount.text = "x" + str(Global.blue_dice_max_amount)
    red_dice_amount.text = "x" + str(Global.red_dice_max_amount)
    
    # Check if we need to add any new dice types
    var dice_types = ["evil", "giant", "magma", "even", "odd", "green", "mech"]
    
    for dice_type in dice_types:
        var max_amount = get_dice_max_amount(dice_type)
        
        if max_amount > 0:
            # If the player has this dice type but it's not displayed yet
            if not dice_displays.has(dice_type):
                # Create new display for this dice type
                var new_dice = blue_dice.duplicate()
                var texture_rect = new_dice.get_node("BlueDiceTexture")
                var amount_label = new_dice.get_node("BlueDiceAmount")
                
                # Rename nodes
                new_dice.name = dice_type.capitalize() + "Dice"
                texture_rect.name = dice_type.capitalize() + "DiceTexture"
                amount_label.name = dice_type.capitalize() + "DiceAmount"
                
                # Update texture
                texture_rect.texture = load("res://assets/images/" + dice_type + "6.png")
                if dice_type == "green":
                    texture_rect.texture = load("res://assets/images/" + dice_type + "1.png")
                if dice_type == "odd":
                    texture_rect.texture = load("res://assets/images/" + dice_type + "7.png")               
                # Add to scene and store reference
                dice_top_bar.add_child(new_dice)
                dice_displays[dice_type] = new_dice
                
                # Adjust position
                new_dice.show()
            
            # Update the amount
            var dice_display = dice_displays[dice_type]
            var amount_label = dice_display.get_node(dice_type.capitalize() + "DiceAmount")
            amount_label.text = "x" + str(max_amount)
    

func _start_run() -> void:
    stats = RunStats.new()
    _setup_event_connections()
    _setup_top_bar()
    map.generate_new_map()
    map.unlock_floor(0)



func _change_view(scene: PackedScene) -> Node:
    print(scene)
    if current_view.get_child_count() > 0:
        current_view.get_child(0).queue_free()
        
    get_tree().paused = false
    var new_view := scene.instantiate()
    current_view.add_child(new_view)
    map.hide_map()
    
    return new_view
    
func _show_map() -> void:
    if Global.tutorial_dice_shop_explanation_needed:
        dice_shop_explanation_box.show()
        Global.tutorial_dice_shop_explanation_needed = false
    SFXPlayer.play(Global.sfx_click)
    if current_view.get_child_count() > 0:
        current_view.get_child(0).queue_free()
    dice_shop.show()
    map.show_map()
    map.unlock_next_rooms()


func _setup_event_connections() -> void:
    Events.battle_won.connect(_on_battle_won)
    Events.battle_reward_exited.connect(_show_map)
    Events.event_exited.connect(_show_map)
    Events.map_exited.connect(_on_map_exited)
    Events.shop_exited.connect(_show_map)
    Events.show_reward.connect(_on_show_reward)
    Events.treasure_room_exited.connect(_on_treasure_room_exited)
    Events.campfire_exited.connect(_show_map)
    dice_shop.pressed.connect(_on_dice_shop_pressed)


    
    battle_button.pressed.connect(_change_view.bind(BATTLE_SCENE))
    map_button.pressed.connect(_show_map)
    rewards_button.pressed.connect(_change_view.bind(BATTLE_REWARD_SCENE))
    shop_button.pressed.connect(_change_view.bind(SHOP_SCENE))
    
    
func _setup_top_bar():
    gold_ui.run_stats = stats
    relic_handler.add_relic(character.starting_relic)
    deck_button.card_pile = character.deck
    deck_view.card_pile = character.deck
    deck_button.pressed.connect(deck_view.show_current_view.bind("Deck"))
    
func _on_battle_room_entered(room: Room) ->  void:
    var battle_scene: Battle = _change_view(BATTLE_SCENE) as Battle
    battle_scene.char_stats = character 
    battle_scene.relics = relic_handler
    # Instead of using the battle from the room, get a unique one
    var tier = _get_tier_for_room(room)
    var battle_stats = _get_unique_battle_for_tier(tier)
    
    # Store the selected battle on the room for reward logic
    room.battle_stats = battle_stats
    battle_scene.battle_stats = battle_stats
    
    battle_scene.start_battle()
    dice_shop.hide()
    
func _on_treasure_room_entered() -> void:
    var treasure_scene := _change_view(TREASURE_SCENE) as Treasure
    treasure_scene.relic_handler = relic_handler
    treasure_scene.char_stats = character 
    treasure_scene.generate_relic()
    
func _on_treasure_room_exited(relic: Relic) -> void:
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats
    reward_scene.character_stats = character 
    reward_scene.relic_handler= relic_handler
    
    reward_scene.add_relic_reward(relic)
    
func _on_campfire_room_entered() -> Node:
    var campfire_scene := _change_view(CAMPFIRE_SCENE)
    return campfire_scene 

func _on_shop_entered() -> void:
    var shop := _change_view(SHOP_SCENE) as Shop
    dice_shop.hide()
    shop.char_stats = character
    shop.run_stats = stats
    shop.relic_handler = relic_handler
    shop.populate_shop()


# Helper function to determine battle tier based on room position
func _get_tier_for_room(room: Room) -> int:
    if room.type == Room.Type.BOSS:
        return 4
    elif room.type == Room.Type.ELITE:
        return 3
    elif room.row > 8:
        return 1
    elif room.row > 2:
        return 1
    else:
        return 0


# Get a unique battle that hasn't been used in this run
func _get_unique_battle_for_tier(tier: int) -> BattleStats:
    if Global.tutorial_fight == true && Global.tutorial_on:
        print("specific fight chosen")
        var crab_fight: BattleStats = load("res://battles/tier_0_crab.tres")
        used_battles.append(crab_fight) # optional but recommended
        Global.tutorial_fight = false   # so only the first fight is forced
        Global.tutorial_dice_shop_explanation_needed = true
        return crab_fight
    var available_battles = battle_stats_pool._get_all_battles_for_tier(tier)
    
    # Filter out used battles
    var unused_battles: Array[BattleStats] = []
    for battle in available_battles:
        if not used_battles.has(battle):
            unused_battles.append(battle)
    
    # If we've used all battles, reset for this tier
    if unused_battles.is_empty():
        print("Warning: All battles for tier " + str(tier) + " have been used. Resetting used battles for this tier.")
        # Clear out used battles of this tier
        var i = 0
        while i < used_battles.size():
            if used_battles[i].battle_tier == tier:
                used_battles.remove_at(i)
            else:
                i += 1
                
        # Try again with all battles for this tier available
        return _get_unique_battle_for_tier(tier)
    
    # Select a random battle using the weight system
    var total_weight = 0.0
    for battle in unused_battles:
        total_weight += battle.weight
    
    var roll = randf_range(0.0, total_weight)
    var current_weight = 0.0
    
    for battle in unused_battles:
        current_weight += battle.weight
        if current_weight >= roll:
            used_battles.append(battle)
            if battle.group != "":
                for other in battle_stats_pool.pool:
                    if other.group == battle.group and not used_battles.has(other):
                        used_battles.append(other)
            return battle
    
    # Fallback
    return unused_battles[0]


func _on_event_room_entered(room: Room) ->  void:

    var event_scene: Node = _change_view(EVENT_SCENE) as Battle
    event_scene.char_stats = character 
    event_scene.event_stats = room.event_stats
    #event_scene.start_battle()
    dice_shop.hide()
    audio_player.stream = load("res://sounds/openshopsound.wav")
    audio_player.play()

    
    
# Helper function to generate a relic for elite rewards
func _generate_elite_relic() -> Relic:
    if not elite_relic_pool:
        push_error("No elite relic pool assigned!")
        return null
    return elite_relic_pool.get_random_relic(character, relic_handler)

func _on_battle_won() -> void:
    print("battle won!")
    Global.cards_played_this_turn = 0
    Global.next_roll_modifier = 0
    Global.dice_type = "blue"
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats           
    reward_scene.character_stats = character 
    reward_scene.relic_handler = relic_handler
    reward_scene.add_gold_reward(map.last_room.battle_stats.roll_gold_reward())
    reward_scene.add_card_reward()
    
    # Add relic reward for elite fights

    if map.last_room.type == Room.Type.ELITE:
        var elite_relic = _generate_elite_relic()
        if elite_relic != null:
            reward_scene.add_relic_reward(elite_relic)
    
    Global.fight_turn = 0

func _on_map_exited(room: Room) -> void:
    dice_shop_explanation_box.hide()
    match room.type:
        Room.Type.MONSTER:
            _on_battle_room_entered(room)
        Room.Type.ELITE:
            _on_battle_room_entered(room)
        Room.Type.BOSS:
            _on_battle_room_entered(room)
        Room.Type.CAMPFIRE:
            var campfire_scene = _on_campfire_room_entered()
            if campfire_scene.has_method("setup"):
                campfire_scene.setup(character, stats)
        Room.Type.TREASURE:
            _on_treasure_room_entered()
        Room.Type.SHOP:
            _on_shop_entered()
        Room.Type.EVENT:
            # Check if we have events available
            if event_stats_pool.pool.size() > 0:
                # Get a random event from the pool
                var random_event = event_stats_pool.get_random_event_for_tier(0)
                
                if random_event != null:
                    # Get the scene from the random event
                    var scene_to_use = random_event.scene
                    
                    # Remove the event from the pool
                    var index = event_stats_pool.pool.find(random_event)
                    if index != -1:
                        event_stats_pool.pool.remove_at(index)
                        # Recalculate weights after removing an event
                        event_stats_pool.setup()
                    
                    # Use the scene
                    var event_scene = _change_view(scene_to_use)
                    # Add these lines to set relic_handler and char_stats
                    if "relic_handler" in event_scene:
                        event_scene.relic_handler = relic_handler
                    if "char_stats" in event_scene:
                        event_scene.char_stats = character
                    
                    # If your event scenes need access to character or run stats
                    if event_scene.has_method("setup"):
                        event_scene.setup(character, stats)
                else:
                    # Fallback to default event
                    _change_view(EVENT_SCENE)
            else:
                # No events left, use default
                _change_view(EVENT_SCENE)
                
            dice_shop.hide()



func _on_show_reward():
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats
    reward_scene.character_stats = character
    for i in Global.pending_card_rewards:
        reward_scene.add_card_reward()
    Global.pending_card_rewards = 1

func _on_dice_shop_pressed() -> void:
    SFXPlayer.play(sfx_click)
    dice_shop_explanation_box.hide()
    _change_view(DICE_SHOP_SCENE)
    
    
func _on_hp_changed() -> void:
    health_label.text = str(character.health) + "/" + str(Global.player_max_hp)

    
#func _on_update_dice_top_bar():
    #print("updating dice top bar")
    #blue_dice_amount.text = "Blue: " + str(Global.blue_dice_max_amount)
    #red_dice_amount.text = "Red: " + str(Global.red_dice_max_amount)
#
    #

func _on_card_removed(card) -> void:
    print("card being removed")
    print(character.deck)
    character.deck.remove_card(card)
    Global.removing_card = false
    deck_view.hide()  # This hides the deck view after removal

    
func _on_open_deck_view() -> void:
    Global.removing_card = true
    deck_view.show_current_view("Deck")
    SFXPlayer.play(sfx_click)

func _on_show_map_requested() -> void:
    _show_map()

func _on_stop_map_music() -> void:
    map_music.stop()


func _on_start_map_music() -> void:
    map_music.play()

func _on_check_if_can_purchase_dice() -> void:
    if Global.cheapest_dice_price!=null:
        if Global.gold >= Global.cheapest_dice_price:
            affordable_indicator.show()
        elif Global.gold < Global.cheapest_dice_price:
            affordable_indicator.hide()

# New function to handle relic rewards from events
func _on_show_reward_with_relic(relic: Relic) -> void:
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats
    reward_scene.character_stats = character
    reward_scene.relic_handler = relic_handler
    reward_scene.add_relic_reward(relic)


func _on_join_discord_button_pressed() -> void:
    OS.shell_open("https://discord.gg/fah8A2qQx2")
