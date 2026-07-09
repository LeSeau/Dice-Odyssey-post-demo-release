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

const TREASURE_GOLD_REWARD := 50

# --- Act 2 (placeholder content) -----------------------------------------
# Act 2 recycles act-1 fights: each act-local tier draws from a HIGHER act-1
# pool (act-2 floors 1-3 serve act-1 tier-1 fights, everything deeper serves
# act-1 tier-2 fights; elites/boss reuse themselves). The numeric scaling that
# makes them act-2-sized happens at spawn time in battle.gd (ACT2_* constants
# there), not here and not in any .tres file.
const ACT2_SOURCE_TIER := {0: 1, 1: 2, 2: 2, 3: 3, 4: 4}
# Act-2 fights pay more so a 2nd/3rd dice purchase stays reachable under the
# global x1.4 dice-price escalation.
const ACT2_GOLD_MULT := 1.5

@onready var current_view: Node = $CurrentView
@onready var map_button: Button = %MapButton
@onready var consult_map_button: Button = %ConsultMapButton
@onready var battle_button: Button = %BattleButton
@onready var shop_button: Button = %ShopButton
@onready var rewards_button: Button = %RewardsButton
@onready var deck_button: CardPileOpener = %DeckButton
@onready var deck_view: CardPileView = %DeckView
@onready var gold_ui: GoldUI = %GoldUI
@onready var relic_handler: RelicHandler = %RelicHandler

@onready var health_label: Label = $TopBar/BarItems/HBoxContainer/HealthLabel
@onready var floor_label: Label = %FloorLabel


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
@onready var act_banner: CanvasLayer = $ActBanner


@export var event_stats_pool: EventStatsPool
@export var battle_stats_pool: BattleStatsPool 
@export var elite_relic_pool: RelicPool

var stats: RunStats
var character: CharacterStats
var dice_displays = {}
var used_battles: Array[BattleStats] = []  # Track used battles during this run

# Player-facing "peek at the map" toggle (TopBar's ConsultMapButton) - unlike the
# debug MapButton (which destructively frees whatever's in current_view), this
# hides the current view and pauses the tree instead, so battle/event/shop/
# treasure/campfire state is fully intact when closed. See _open_map_consult().
var map_consult_mode := false

# Set when the act-2 boss falls: the run is over, no further checkpoint may be
# written (and the save file has already been deleted in _on_battle_won).
var run_finished := false

# The dice shop panel (unlike battle/event/card-shop/campfire/treasure) doesn't
# cover the whole screen and is meant to float over the visible map, so it's
# instantiated under TopBar (a CanvasLayer, screen-space, immune to the map
# camera's scroll) instead of current_view (world-space - would drift off-center
# whenever the map camera isn't at its floor-0 resting position). Tracked here
# since _change_view()'s current_view bookkeeping doesn't apply to it.
var dice_shop_instance: Node = null

# Armed by _on_battle_won when the act-1 boss falls; fires on the next return to
# the map (i.e. after the boss reward screen), so boss gold/card aren't skipped.
var act_transition_pending := false
# Pristine copy of the event pool, snapshotted before act 1 consumes any of it -
# restored on act 2 entry so act 2 can recycle the same events.
var initial_event_pool: Array[EventStats] = []

var sfx_click = preload("res://sfx/219069__annabloom__click1.wav")

func _ready() -> void:
    call_deferred("_late_init")


func _late_init() -> void:
    # Clean slate for every run - the Global autoload survives scene reloads (death-screen
    # Restart included), so without this a "new" run inherited the previous run's gold/dice/
    # act/tutorial flags. A loaded run restores its own values on top of this reset.
    Global.reset_run_state()
    var warrior = load("res://characters/warrior/warrior.tres")
    character = warrior.create_instance()

    Events.show_reward.connect(_on_show_reward)
    Events.show_reward_with_relic.connect(_on_show_reward_with_relic)
    Events.update_dice_top_bar.connect(_on_update_dice_top_bar)
    Events.hp_changed.connect(_on_hp_changed)
    Events.card_removed.connect(_on_card_removed)
    Events.open_deck_view.connect(_on_open_deck_view)
    Events.open_deck_view_for_upgrade.connect(_on_open_deck_view_for_upgrade)
    Events.show_map_requested.connect(_on_show_map_requested)
    Events.stop_map_music.connect(_on_stop_map_music)
    Events.start_map_music.connect(_on_start_map_music)
    Events.check_if_can_purchase_dice.connect(_on_check_if_can_purchase_dice)

    if Global.load_run_requested:
        Global.load_run_requested = false
        _load_run()
    else:
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
    Global.current_act = 1
    initial_event_pool = event_stats_pool.pool.duplicate()
    _setup_event_connections()
    _setup_top_bar()
    map.generate_new_map()
    map.unlock_floor(0)
    _update_floor_label()
    # First checkpoint right away - starting a new run is also what "abandons" any previous
    # save (single slot, roguelike convention).
    _save_checkpoint()


# floors_climbed is 0 before any room is picked (row 0 is the currently
# available floor) and becomes N right after picking a room on row N-1 - in
# both cases "floors_climbed + 1" is the floor the player is currently on/about
# to enter. Clamped since floors_climbed can reach FLOORS right after picking
# the boss room, one past the last real floor number.
func _update_floor_label() -> void:
    floor_label.text = "Floor: %d" % mini(map.floors_climbed + 1, MapGenerator.FLOORS)



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
    if act_transition_pending:
        _enter_act_2()
    if Global.tutorial_dice_shop_explanation_needed:
        dice_shop_explanation_box.show()
        Global.tutorial_dice_shop_explanation_needed = false
    SFXPlayer.play(Global.sfx_click)
    if current_view.get_child_count() > 0:
        current_view.get_child(0).queue_free()
    if dice_shop_instance:
        dice_shop_instance.queue_free()
        dice_shop_instance = null
    dice_shop.show()
    map.show_map()
    map.unlock_next_rooms()
    # The save checkpoint: every return to the map (post-battle-reward, post-event,
    # post-shop, post-campfire, post-treasure) snapshots the run. Quitting mid-room
    # resumes from here - i.e. back on the map, the room not yet re-entered (v1 scope:
    # no mid-combat saves, see save_manager.gd).
    _save_checkpoint()


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
    consult_map_button.pressed.connect(_on_consult_map_button_pressed)
    
    
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
    # The act-LOCAL tier, not the source battle's own tier label - battle.gd's
    # act-2 scaling keys off this (an act-2 floor-1 fight recycled from the act-1
    # tier-1 pool must be scaled as act-2 tier 0, not as tier 1).
    battle_scene.act_tier = tier
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
    reward_scene.add_gold_reward(TREASURE_GOLD_REWARD)
    
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
    elif room.row > 7:
        return 2
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
    # In act 2 the act-local tier draws from a higher act-1 pool (see
    # ACT2_SOURCE_TIER) - everything below works on the source tier, since that's
    # what the .tres battle_tier labels hold.
    var source_tier: int = tier
    if Global.current_act >= 2:
        source_tier = ACT2_SOURCE_TIER[tier]
    var available_battles = battle_stats_pool._get_all_battles_for_tier(source_tier)

    # Filter out used battles
    var unused_battles: Array[BattleStats] = []
    for battle in available_battles:
        if not used_battles.has(battle):
            unused_battles.append(battle)

    # If we've used all battles, reset for this tier
    if unused_battles.is_empty():
        print("Warning: All battles for tier " + str(source_tier) + " have been used. Resetting used battles for this tier.")
        # Clear out used battles of this tier
        var i = 0
        while i < used_battles.size():
            if used_battles[i].battle_tier == source_tier:
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
    var gold_reward: int = map.last_room.battle_stats.roll_gold_reward()
    if Global.current_act >= 2:
        gold_reward = roundi(gold_reward * ACT2_GOLD_MULT)
    reward_scene.add_gold_reward(gold_reward)
    reward_scene.add_card_reward()

    # Add relic reward for elite fights

    if map.last_room.type == Room.Type.ELITE:
        var elite_relic = _generate_elite_relic()
        if elite_relic != null:
            reward_scene.add_relic_reward(elite_relic)

    # Beating the act-1 boss arms the act transition; _show_map performs it once
    # the reward screen is exited (see _enter_act_2).
    if map.last_room.type == Room.Type.BOSS and Global.current_act == 1:
        act_transition_pending = true

    # Beating the act-2 boss ends the run - drop the save (roguelike: a finished run
    # can't be reloaded). run_finished also stops _show_map's checkpoint from writing
    # a useless "post-boss map with nothing left to do" save when the reward screen exits.
    if map.last_room.type == Room.Type.BOSS and Global.current_act >= 2:
        run_finished = true
        SaveManager.delete_save()

    Global.fight_turn = 0

# One-shot act transition. Deck, relics, gold and dice all carry over untouched -
# only the map resets, plus the agreed free full heal (act transition = free
# campfire) and a fresh event pool so act 2 can re-serve act-1 events.
func _enter_act_2() -> void:
    act_transition_pending = false
    Global.current_act = 2
    character.health = character.max_health
    Events.hp_changed.emit()
    used_battles.clear()
    event_stats_pool.pool = initial_event_pool.duplicate()
    map.generate_new_map()
    map.unlock_floor(0)
    _update_floor_label()
    act_banner.announce("ACT 2: THE CATACOMBS")


func _on_map_exited(room: Room) -> void:
    # Room clicks are blocked at the input level while consulting the map (see
    # _open_map_consult - the tree is paused and Map isn't PROCESS_MODE_ALWAYS),
    # but guard here too in case this is ever reached some other way - consulting
    # the map must never be able to trigger entering a new room.
    if map_consult_mode:
        return
    dice_shop_explanation_box.hide()
    _update_floor_label()
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
            if room.is_secret_fight:
                _on_battle_room_entered(room)
                return
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
    if dice_shop_instance:
        dice_shop_instance.queue_free()
    dice_shop_instance = DICE_SHOP_SCENE.instantiate()
    $TopBar.add_child(dice_shop_instance)
    map.show_map()
    
    
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

func _on_open_deck_view_for_upgrade() -> void:
    Global.upgrading_card = true
    deck_view.show_current_view("Upgrade a Card")
    SFXPlayer.play(sfx_click)

func _on_show_map_requested() -> void:
    _show_map()

# Non-destructive "peek at the map" (STS-style), from battle/event/shop/treasure/
# campfire. Unlike _show_map() (used by the debug MapButton and real map-to-map
# transitions), this never frees current_view's child - it just hides it and
# pauses the tree, so whatever's underneath (an in-progress battle, an event
# dialogue, a shop) is exactly as the player left it when they close the map again.
func _on_consult_map_button_pressed() -> void:
    if map_consult_mode:
        _close_map_consult()
    else:
        _open_map_consult()

func _open_map_consult() -> void:
    if current_view.get_child_count() == 0:
        return  # already looking at the map itself - nothing to peek behind
    map_consult_mode = true
    var view := current_view.get_child(0)
    view.hide()
    _set_nested_canvas_layers_visible(view, false)
    # Camera2D isn't a CanvasItem, so hiding the view above does nothing to its own
    # camera (battle.tscn has one) - it would stay "current" and keep driving the
    # viewport, fighting Map's camera for control (this is why scrolling the map
    # during consult previously had no visible effect - you were moving Map's
    # camera while the battle's own camera was still the one actually active).
    # Disable it BEFORE enabling Map's own camera below so there's never a moment
    # with two enabled cameras contending for "current".
    _set_nested_cameras_enabled(view, false)
    map.show_map()
    # Force-clear any relic tooltip that's mid-hover before pausing - relic_ui.gd's
    # main tooltip has no safety timeout (only mouse_exited/_exit_tree free it, and
    # neither fires on a paused, non-ALWAYS node), so without this it would sit on
    # screen for the entire time the map is up and stay stuck after closing it too.
    for relic_ui in relic_handler.relics.get_children():
        if relic_ui.has_method("_cleanup_tooltips"):
            relic_ui._cleanup_tooltips()
    # Pausing (same pattern as battle_over_panel.gd) freezes whatever's hidden
    # underneath - enemy turns, event timers, shop animations - so nothing
    # progresses invisibly while the map is up. ConsultMapButton itself is
    # process_mode=ALWAYS (set in run.tscn) so it still receives the click that
    # closes this again; Map/rooms are left at their default process mode, so
    # (on top of the map_consult_mode guard in _on_map_exited) room clicks can't
    # register at all while paused - consulting can never accidentally select a room.
    get_tree().paused = true
    consult_map_button.text = "Close Map"

func _close_map_consult() -> void:
    map_consult_mode = false
    get_tree().paused = false
    map.hide_map()
    if current_view.get_child_count() > 0:
        var view := current_view.get_child(0)
        view.show()
        _set_nested_canvas_layers_visible(view, true)
        _set_nested_cameras_enabled(view, true)
    consult_map_button.text = "Map"

# See _open_map_consult() - a hidden view's own Camera2D (not a CanvasItem) keeps
# running/staying current unless explicitly disabled, same class of gotcha as
# _set_nested_canvas_layers_visible below but for cameras instead of CanvasLayers.
func _set_nested_cameras_enabled(node: Node, enabled: bool) -> void:
    for child in node.get_children():
        if child is Camera2D:
            child.enabled = enabled
        _set_nested_cameras_enabled(child, enabled)

# hide()/show() on a view's root only propagates to normal CanvasItem children -
# any CanvasLayer anywhere in its subtree (battle.tscn alone has 5: BattleUI/
# CardPileViews/BattleOverLayer/RedFlash/an unnamed one) draws independently of
# its parent's visibility and must be toggled explicitly, same root cause as the
# MapBackground leak documented in CLAUDE.md. Recurses past CanvasLayers too, in
# case one ever nests another.
func _set_nested_canvas_layers_visible(node: Node, is_visible: bool) -> void:
    for child in node.get_children():
        if child is CanvasLayer:
            child.visible = is_visible
        _set_nested_canvas_layers_visible(child, is_visible)

func _on_stop_map_music() -> void:
    map_music.stop()


func _on_start_map_music() -> void:
    map_music.play()

func _on_check_if_can_purchase_dice() -> void:
    if Global.cheapest_dice_price!=null:
        if Global.gold >= Global.cheapest_dice_price:
            affordable_indicator.show()
            dice_shop.set_blinking(true)
        elif Global.gold < Global.cheapest_dice_price:
            affordable_indicator.hide()
            dice_shop.set_blinking(false)

# New function to handle relic rewards from events
func _on_show_reward_with_relic(relic: Relic) -> void:
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats
    reward_scene.character_stats = character
    reward_scene.relic_handler = relic_handler
    reward_scene.add_relic_reward(relic)


func _on_join_discord_button_pressed() -> void:
    OS.shell_open("https://discord.gg/fah8A2qQx2")


# =========================================================
# SAVE / LOAD (v1: map-screen checkpoints only, single slot)
# See global/save_manager.gd for the format/scope rationale.
# =========================================================

const DICE_TYPES := ["blue", "red", "evil", "green", "giant", "magma", "even", "odd", "mech"]

# The one-shot tutorial/explanation flags that matter ACROSS rooms (a loaded run must not
# replay the forced first fight or re-show already-seen explanation panels). The many
# within-combat tutorial flags aren't listed - a load always lands on the map, where
# reset_run_state() defaults are correct for them.
const SAVED_TUTORIAL_FLAGS := [
    "tutorial_on", "tutorial_fight", "tutorial_block", "tutorial_enemy_attack",
    "tutorial_reset_power_warning",
    "tutorial_bonus_requirement_explanation_needed",
    "tutorial_transcendent_explanation_needed",
    "tutorial_dice_shop_explanation_needed",
    "tutorial_blessing_explanation_needed",
]


func _save_checkpoint() -> void:
    if run_finished:
        return

    # Cards are saved as {path, id} pairs: path is the primary key (all deck cards are
    # shared file-backed resources today), id is a fallback so a future code path that
    # duplicates a Card resource (duplicates lose their resource_path) degrades to an
    # id lookup instead of silently dropping the card from the save.
    var deck_out: Array = []
    for card: Card in character.deck.cards:
        if card.resource_path == "" and card.id == "":
            push_warning("Save: deck card with neither resource_path nor id - skipped")
            continue
        deck_out.append({"path": card.resource_path, "id": card.id})

    var relics_out: Array = []
    for relic: Relic in relic_handler.get_all_relics():
        if relic.resource_path == "":
            push_warning("Save: relic '%s' has no resource_path - skipped" % relic.id)
            continue
        relics_out.append(relic.resource_path)

    var dice_out := {}
    for type: String in DICE_TYPES:
        dice_out[type] = Global.get(type + "_dice_max_amount")

    var tutorials_out := {}
    for flag: String in SAVED_TUTORIAL_FLAGS:
        tutorials_out[flag] = Global.get(flag)

    var used_battles_out: Array = []
    for battle: BattleStats in used_battles:
        if battle.resource_path != "":
            used_battles_out.append(battle.resource_path)

    var event_pool_out: Array = []
    for event: EventStats in event_stats_pool.pool:
        if event.resource_path != "":
            event_pool_out.append(event.resource_path)
    var initial_event_pool_out: Array = []
    for event: EventStats in initial_event_pool:
        if event.resource_path != "":
            initial_event_pool_out.append(event.resource_path)

    SaveManager.write_save({
        "act": Global.current_act,
        "gold": Global.gold,
        "health": character.health,
        "max_health": character.max_health,
        "player_max_hp": Global.player_max_hp,
        "deck": deck_out,
        "relics": relics_out,
        "dice_max": dice_out,
        "dice_inventory": Global.dice_inventory.duplicate(),
        "purchased_dice_counts": Global.purchased_dice_counts.duplicate(),
        "shop_initialized": Global.shop_initialized,
        "shop_dice_selection": Global.shop_dice_selection.duplicate(),
        "cheapest_dice_price": Global.cheapest_dice_price,
        "tutorials": tutorials_out,
        "used_battles": used_battles_out,
        "event_pool_remaining": event_pool_out,
        "event_pool_initial": initial_event_pool_out,
        "run_stats": {
            "card_rewards": stats.card_rewards,
            "normal_weight": stats.normal_weight,
            "support_weight": stats.support_weight,
        },
        "map": map.get_save_data(),
    })


# Mirrors _start_run()'s structure but restores every piece from the save instead of
# generating fresh. Runs on top of the reset_run_state() clean slate from _late_init.
func _load_run() -> void:
    var data := SaveManager.read_save()
    if data.is_empty():
        push_warning("Load Run: no usable save found - starting a fresh run instead")
        _start_run()
        return

    stats = RunStats.new()
    stats.card_rewards = data["run_stats"]["card_rewards"]
    stats.normal_weight = data["run_stats"]["normal_weight"]
    stats.support_weight = data["run_stats"]["support_weight"]

    Global.current_act = data["act"]
    Global.gold = data["gold"]
    stats.gold = data["gold"]
    Global.player_max_hp = data["player_max_hp"]

    for type: String in DICE_TYPES:
        var max_amount: int = data["dice_max"].get(type, 0)
        Global.set(type + "_dice_max_amount", max_amount)
        # current gets recomputed at each battle start anyway; max is a safe map-screen value
        Global.set(type + "_dice_current_amount", max_amount)
    Global.dice_inventory = data["dice_inventory"]
    Global.purchased_dice_counts = data["purchased_dice_counts"]
    Global.shop_initialized = data["shop_initialized"]
    Global.shop_dice_selection = data["shop_dice_selection"]
    Global.cheapest_dice_price = data["cheapest_dice_price"]

    for flag: String in SAVED_TUTORIAL_FLAGS:
        if data["tutorials"].has(flag):
            Global.set(flag, data["tutorials"][flag])

    # max_health BEFORE health - Stats.set_health clamps against the current max.
    character.max_health = data["max_health"]
    character.health = data["health"]

    var restored_deck := CardPile.new()
    var id_lookup := _build_card_id_lookup()
    for entry: Dictionary in data["deck"]:
        var card: Card = null
        if entry["path"] != "" and ResourceLoader.exists(entry["path"]):
            card = load(entry["path"])
        elif id_lookup.has(entry["id"]):
            card = id_lookup[entry["id"]]
        if card:
            restored_deck.add_card(card)
        else:
            push_warning("Load Run: card '%s' (%s) no longer exists - dropped from deck" % [entry["id"], entry["path"]])
    character.deck = restored_deck

    var restored_events: Array[EventStats] = []
    for path: String in data["event_pool_remaining"]:
        if ResourceLoader.exists(path):
            restored_events.append(load(path))
    event_stats_pool.pool = restored_events
    event_stats_pool.setup()
    var restored_initial_events: Array[EventStats] = []
    for path: String in data["event_pool_initial"]:
        if ResourceLoader.exists(path):
            restored_initial_events.append(load(path))
    initial_event_pool = restored_initial_events

    used_battles.clear()
    for path: String in data["used_battles"]:
        if ResourceLoader.exists(path):
            used_battles.append(load(path))

    _setup_event_connections()
    _setup_top_bar()  # adds the starting relic; saved relics below dedupe via has_relic

    for path: String in data["relics"]:
        if not ResourceLoader.exists(path):
            push_warning("Load Run: relic %s no longer exists - dropped" % path)
            continue
        relic_handler.add_relic(load(path))

    map.load_from_save_data(data["map"])
    if map.last_room != null:
        map.unlock_next_rooms()
    else:
        map.unlock_floor(0)
    map.show_map()
    dice_shop.show()
    _update_floor_label()
    Events.hp_changed.emit()
    Events.check_if_can_purchase_dice.emit()


# Path-independent card lookup for the deck-restore id fallback: every card that can
# legally be in a deck is reachable from the warrior's draftable pool or starting deck,
# plus their upgraded ("+") versions.
func _build_card_id_lookup() -> Dictionary:
    var lookup := {}
    var sources: Array[CardPile] = [character.draftable_cards, character.starting_deck]
    for pile: CardPile in sources:
        if pile == null:
            continue
        for card: Card in pile.cards:
            lookup[card.id] = card
            if card.upgraded_version:
                lookup[card.upgraded_version.id] = card.upgraded_version
    return lookup
