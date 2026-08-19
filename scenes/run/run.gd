class_name Run
extends Node

const BATTLE_SCENE := preload ("res://scenes/battle/battle.tscn")
const BATTLE_REWARD_SCENE := preload ("res://scenes/battle_reward/battle_reward.tscn")
const BOSS_SCENE := preload ("res://scenes/battle/battle.tscn")
const TREASURE_SCENE := preload ("res://scenes/treasure/treasure.tscn")
const CAMPFIRE_SCENE := preload ("res://scenes/campfire/campfire.tscn")
const EVENT_SCENE := preload("res://scenes/events/event_add_new_card.tscn")
const DICE_SHOP_SCENE = preload("res://scenes/shop/dice_shop.tscn")
const DICE_INFUSION_SCENE := preload("res://scenes/dice_infusion/dice_infusion.tscn")
const DICE_LOADOUT_SCENE := preload("res://scenes/dice_loadout/dice_loadout.tscn")

const SHOP_SCENE := preload ("res://scenes/shop/card_shop.tscn")

const TREASURE_GOLD_REWARD := 50

# The tutorial fight is a solo Skeleton, and so is this pool entry - drawing it on floor 1-3
# right after the tutorial replays the exact same fight (Julien, 2026-07-31: "should be a
# 1 time fight only"). Burned from the pool for the rest of the run the moment the tutorial
# fight is served. Safe for tier 0: 12 entries, 9 of them collapse into the "slimes" group,
# so 3 distinct picks remain for the 3 tier-0 floors even with this one gone.
const TUTORIAL_TWIN_BATTLE := "res://battles/tier_0_crab.tres"

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
@onready var consult_map_button: TextureButton = %ConsultMapButton
@onready var consult_map_button_hover_glow: Panel = %HoverGlow
@onready var pause_button: TextureButton = %PauseButton
@onready var pause_button_hover_glow: Panel = get_node("%PauseButton/PauseHoverGlow")
@onready var pause_menu: PauseMenu = %PauseMenu
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
const DiceBarTooltipScene := preload("res://scenes/ui/dice_tooltip.tscn")
# Hover tooltip for the top-bar dice counters (same dice_tooltip the combat interface and
# dice shop use - type name in its color + faces + infusion line). One at a time.
var _dice_bar_tooltip: Node = null

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
    # Dev shortcuts (Map/Battle buttons): keep them for in-editor staging/screenshot
    # work, hide them from the release export players get (launch checklist item).
    $DebugButtons.visible = OS.is_debug_build()
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
    Events.show_reward_with_relic_and_gold.connect(_on_show_reward_with_relic_and_gold)
    Events.update_dice_top_bar.connect(_on_update_dice_top_bar)
    Events.hp_changed.connect(_on_hp_changed)
    Events.card_removed.connect(_on_card_removed)
    Events.open_deck_view.connect(_on_open_deck_view)
    Events.open_deck_view_for_upgrade.connect(_on_open_deck_view_for_upgrade)
    Events.show_map_requested.connect(_on_show_map_requested)
    Events.dice_shop_closed.connect(_on_dice_shop_closed)
    Events.stop_map_music.connect(_on_stop_map_music)
    Events.start_map_music.connect(_on_start_map_music)
    Events.check_if_can_purchase_dice.connect(_on_check_if_can_purchase_dice)
    Events.dice_price_changed.connect(_on_dice_price_changed)
    Events.end_screen_hud_visibility.connect(_on_end_screen_hud_visibility)
    # Blue/Red live in the .tscn; every other type is attached where it's duplicated
    # (runtime connects are non-persistent, so duplicate() does NOT copy these).
    _attach_dice_bar_tooltip(blue_dice, "blue")
    _attach_dice_bar_tooltip(red_dice, "red")

    if Global.load_run_requested:
        Global.load_run_requested = false
        _load_run()
    else:
        _start_run()
    _on_update_dice_top_bar()
    map_music.play()


# The RelicBar and the Discord pin live on CanvasLayers, so they float above EVERY view -
# including the full-screen end panels (Game Over / Act 1 Complete / Dungeon Conquered),
# where 5+ relic icons land straight on the panel title. The panels ask for them to be
# hidden while they're up; Act 1 Complete's Continue restores them (the one exit where the
# run keeps going - every other exit destroys this scene anyway).
func _on_end_screen_hud_visibility(hud_visible: bool) -> void:
    var relic_bar := get_node_or_null("TopBar/RelicBar")
    if relic_bar:
        relic_bar.visible = hud_visible
    var discord_pin := get_node_or_null("CanvasLayer/JoinDiscordControl")
    if discord_pin:
        discord_pin.visible = hud_visible


    
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
        _attach_dice_bar_tooltip(new_dice, dice_type)

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


# Top-bar dice counters are passive displays: the VBox takes the hover, its children are
# silenced so the TextureRect can't steal mouse_entered from it.
func _attach_dice_bar_tooltip(container: Control, dice_type: String) -> void:
    container.mouse_filter = Control.MOUSE_FILTER_STOP
    for child in container.get_children():
        if child is Control:
            child.mouse_filter = Control.MOUSE_FILTER_IGNORE
    container.mouse_entered.connect(_show_dice_bar_tooltip.bind(container, dice_type))
    container.mouse_exited.connect(_hide_dice_bar_tooltip)


func _show_dice_bar_tooltip(container: Control, dice_type: String) -> void:
    _hide_dice_bar_tooltip()  # kill-before-spawn: one tooltip at a time
    _dice_bar_tooltip = DiceBarTooltipScene.instantiate()
    Global.add_tooltip(_dice_bar_tooltip, self)
    var panel = _dice_bar_tooltip.get_node("DiceTooltip")
    panel.get_tooltip_content(dice_type)
    # Below the hovered counter, clamped so the 204px panel never leaves the screen.
    var rect := container.get_global_rect()
    panel.show_tooltip(Vector2(clampf(rect.get_center().x - 102.0, 8.0, 1068.0), rect.end.y + 10.0))


func _hide_dice_bar_tooltip() -> void:
    if _dice_bar_tooltip and is_instance_valid(_dice_bar_tooltip):
        _dice_bar_tooltip.queue_free()
    _dice_bar_tooltip = null

# Updated function to handle all dice types
func _on_update_dice_top_bar() -> void:

    # Always update blue and red dice (starting dice)
    blue_dice_amount.text = "x" + str(Global.blue_dice_max_amount)
    red_dice_amount.text = "x" + str(Global.red_dice_max_amount)
    # Blue and Red used to be assumed permanent, but a run loadout (dice_loadout.gd)
    # can now start a run without either (and Red can be traded away via
    # event_hollow_idol.gd) - hide them at 0 the same way every other dice type
    # already hides itself.
    blue_dice.visible = Global.blue_dice_max_amount > 0
    red_dice.visible = Global.red_dice_max_amount > 0

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
                _attach_dice_bar_tooltip(new_dice, dice_type)

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
    # Run-identity beat (the "wish"): from the player's second run onward, the dice
    # loadout picker (scenes/dice_loadout) precedes the map. Run #1 and tutorial runs
    # keep the classic 2 Blue + 1 Red already in place from reset_run_state - the
    # tutorial scripts Blue rolls and a Red socket, and a brand-new player shouldn't
    # face a 5-way archetype choice with zero context. The stat is counted BEFORE the
    # branch (so the run being started is itself run #N) and flushed immediately -
    # quitting from the very first map must still mark run #1 as played.
    var offer_loadout: bool = AchievementManager.get_stat("runs_started") >= 1 and not Global.tutorial_on
    AchievementManager.add_stat("runs_started", 1)
    AchievementManager.flush()
    if offer_loadout:
        _show_dice_loadout()
        return
    # Act 1 gets the same announcement beat act 2 always had (_enter_act_2) - the map is
    # the first thing a player ever sees, and it opened with zero framing before this.
    act_banner.announce("ACT 1: THE RUINS")
    # First checkpoint right away - starting a new run is also what "abandons" any previous
    # save (single slot, roguelike convention).
    _save_checkpoint()


# floors_climbed is 0 before any room is picked (row 0 is the currently
# available floor) and becomes N right after picking a room on row N-1 - in
# both cases "floors_climbed + 1" is the floor the player is currently on/about
# to enter. Clamped since floors_climbed can reach FLOORS right after picking
# the boss room, one past the last real floor number. map.floors_climbed is
# act-local (each act generates its own fresh map starting back at 0), so the
# displayed floor number is offset by the floor count of all completed acts -
# otherwise act 2 would visibly restart the count at "Floor: 1".
func _update_floor_label() -> void:
    var floor_in_act := mini(map.floors_climbed + 1, MapGenerator.FLOORS)
    var completed_acts_offset := (Global.current_act - 1) * MapGenerator.FLOORS
    var current_floor := completed_acts_offset + floor_in_act
    floor_label.text = "Floor: %d" % current_floor
    # End-of-run screens stat: deepest floor the run has reached (maxi keeps it
    # monotonic - re-showing the map can only re-show a floor, never un-reach it).
    Global.run_stat_highest_floor = maxi(Global.run_stat_highest_floor, current_floor)



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
    # Whatever hid the run HUD (an event panel, the card-reward picker, an end screen's
    # Continue) is done by the time we're back on the map, so restore it unconditionally
    # here rather than pairing every hide with its own show - one screen forgetting would
    # otherwise leave the player without a relic bar for the rest of the run.
    Events.end_screen_hud_visibility.emit(true)
    # Act transition beat: the first return to the map after the act-1 boss (i.e. right
    # after the boss reward screen exits) is intercepted by the dice infusion screen.
    # The actual act-2 entry (heal, new map, ACT 2 banner) happens in
    # _on_dice_infusion_completed, so the banner isn't wasted under the infusion screen.
    if act_transition_pending:
        act_transition_pending = false
        _show_dice_infusion()
        return
    if Global.tutorial_dice_shop_explanation_needed:
        _align_dice_shop_explanation()
        dice_shop_explanation_box.show()
        Global.tutorial_dice_shop_explanation_needed = false
    SFXPlayer.play(Global.sfx_click)
    if current_view.get_child_count() > 0:
        current_view.get_child(0).queue_free()
    if dice_shop_instance:
        dice_shop_instance.queue_free()
        dice_shop_instance = null
    dice_shop.set_available(true)
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
    Events.dice_infusion_completed.connect(_on_dice_infusion_completed)
    Events.dice_loadout_completed.connect(_on_dice_loadout_completed)
    Events.event_exited.connect(_show_map)
    Events.map_exited.connect(_on_map_exited)
    Events.shop_exited.connect(_show_map)
    Events.show_reward.connect(_on_show_reward)
    Events.treasure_room_exited.connect(_on_treasure_room_exited)
    Events.campfire_exited.connect(_show_map)
    dice_shop.pressed.connect(_on_dice_shop_pressed)


    
    battle_button.pressed.connect(_on_debug_battle_button_pressed)
    map_button.pressed.connect(_show_map)
    rewards_button.pressed.connect(_change_view.bind(BATTLE_REWARD_SCENE))
    shop_button.pressed.connect(_change_view.bind(SHOP_SCENE))
    consult_map_button.pressed.connect(_on_consult_map_button_pressed)
    consult_map_button.mouse_entered.connect(_on_consult_map_button_mouse_entered)
    consult_map_button.mouse_exited.connect(_on_consult_map_button_mouse_exited)
    pause_button.pressed.connect(_on_pause_button_pressed)
    pause_button.mouse_entered.connect(_on_pause_button_mouse_entered)
    pause_button.mouse_exited.connect(_on_pause_button_mouse_exited)
    pause_menu.opened.connect(_on_pause_menu_opened)
    pause_menu.closed.connect(_on_pause_menu_closed)
    
    
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
    dice_shop.set_available(false)
    
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
    dice_shop.set_available(false)
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
        # Dedicated tutorial content (battles/tutorial_fight.tres), not the real
        # tier_0_crab pool entry - not appended to used_battles since it isn't in any
        # pool and should never affect no-repeat tracking for the rest of the run.
        var tutorial_fight: BattleStats = load("res://battles/tutorial_fight.tres")
        Global.tutorial_fight = false   # so only the first fight is forced
        Global.tutorial_dice_shop_explanation_needed = true
        _burn_tutorial_twin_battle()
        return tutorial_fight
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


# Marks the pool's solo-Skeleton fight as already used, so the tutorial is the only time you
# see it. Matched on resource_path against the live pool (the SAME object the draw filters on,
# so used_battles.has() lines up) and it rides the save file for free - used_battles is
# persisted by path. If tier 0 ever exhausts, the tier reset lets it back in rather than
# hard-locking the draw; that only happens past 3 tier-0 fights, which act 1 can't reach.
func _burn_tutorial_twin_battle() -> void:
    for battle: BattleStats in battle_stats_pool.pool:
        if battle.resource_path == TUTORIAL_TWIN_BATTLE and not used_battles.has(battle):
            used_battles.append(battle)
            return


func _on_event_room_entered(room: Room) ->  void:

    var event_scene: Node = _change_view(EVENT_SCENE) as Battle
    event_scene.char_stats = character 
    event_scene.event_stats = room.event_stats
    #event_scene.start_battle()
    dice_shop.set_available(false)
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
    Global.dice_type = Global.default_active_dice_type()
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats
    reward_scene.character_stats = character
    reward_scene.relic_handler = relic_handler
    var gold_reward: int = map.last_room.battle_stats.roll_gold_reward()
    if Global.current_act >= 2:
        gold_reward = roundi(gold_reward * ACT2_GOLD_MULT)
    reward_scene.add_gold_reward(gold_reward)
    reward_scene.add_card_reward()

    # Card-reward rarity odds branch on room type (BattleReward.RewardContext) - boss rooms
    # get all-Rare offers, elites get boosted Uncommon/Rare odds, everything else is the base
    # weighted draw. Must be set before the player can click the "Add New Card" button, so
    # right here is early enough regardless of room type.
    if map.last_room.type == Room.Type.BOSS:
        reward_scene.reward_context = BattleReward.RewardContext.BOSS
        # Both act bosses are the Leviathan (same resource, act-2 scaled).
        AchievementManager.unlock("marine")
    elif map.last_room.type == Room.Type.ELITE:
        reward_scene.reward_context = BattleReward.RewardContext.ELITE
        AchievementManager.unlock("not_impressed")

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
        AchievementManager.unlock("conqueror")

    Global.fight_turn = 0

# One-shot act transition. Deck, relics, gold and dice all carry over untouched -
# only the map resets, plus the agreed free full heal (act transition = free
# campfire). event_stats_pool is deliberately left as-is (NOT reset to
# initial_event_pool) so events already seen in act 1 don't come back in act 2 -
# the pool only ever shrinks as events get drawn (see the EVENT room case above),
# same pool object carries the depletion across the transition. used_battles IS
# cleared though, since fights are recycled/rescaled per act (see
# _apply_act2_scaling) rather than being a one-time-per-run pool like events.
# The act-transition "ancient power" beat (STS2 ancient-relic style): after the act-1
# boss reward screen exits, the dice infusion screen takes over current_view instead of
# the map. It reads Global itself (owned dice types) and reports back through
# Events.dice_infusion_completed - no setup args needed.
func _show_dice_infusion() -> void:
    dice_shop.set_available(false)
    _change_view(DICE_INFUSION_SCENE)


func _on_dice_infusion_completed() -> void:
    _enter_act_2()
    _show_map()


# The run-identity picker ("the wish", scenes/dice_loadout) - run #2+ only, see
# _start_run. Mirrors _show_dice_infusion: a full-screen ceremony in current_view that
# reports back through Events.dice_loadout_completed. Deliberately NO _save_checkpoint
# before the pick: the previous run's save survives until the wish is confirmed, so
# quitting mid-picker abandons nothing.
func _show_dice_loadout() -> void:
    dice_shop.set_available(false)
    _change_view(DICE_LOADOUT_SCENE)


func _on_dice_loadout_completed() -> void:
    # The picker already wrote the chosen dice amounts into Global (state first,
    # flourish after - same principle as the infusion screen). Refresh the top bar,
    # then open the run exactly like _start_run's direct path: banner, then the map -
    # whose _show_map() writes the run's first checkpoint, which is the moment the
    # previous run's save is finally replaced.
    _on_update_dice_top_bar()
    act_banner.announce("ACT 1: THE RUINS")
    _show_map()


func _enter_act_2() -> void:
    act_transition_pending = false
    Global.current_act = 2
    character.health = character.max_health
    Events.hp_changed.emit()
    # Defensive re-derive before the fresh map paints its badges (unlock_floor below
    # refreshes them) - the price listener should keep this fresh, but act transition is
    # exactly where a stale value gets painted onto every room at once.
    Global.refresh_cheapest_dice_price()
    used_battles.clear()
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
                var random_event = event_stats_pool.get_random_event_for_tier(0, relic_handler.get_all_relics().size())
                
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
                    # Some older events (event_fountain_heal.gd) use this property name
                    # instead - redundant with setup() below, but a direct safety net in
                    # case that call is ever skipped (has_method false, script error, etc.)
                    # for a scene that still expects character_stats to be non-null.
                    if "character_stats" in event_scene:
                        event_scene.character_stats = character

                    # If your event scenes need access to character or run stats
                    if event_scene.has_method("setup"):
                        event_scene.setup(character, stats)
                else:
                    # Fallback to default event
                    _change_view(EVENT_SCENE)
            else:
                # No events left, use default
                _change_view(EVENT_SCENE)

            dice_shop.set_available(false)
            # Events are the one screen the relic row cannot share the top of the frame with.
            # An event panel needs ~620px of height and starts directly under the 80px top bar,
            # leaving ~15px of slack in a 720px frame - so pushing its title below a relic band
            # only works if the band is ~15px tall, i.e. unusably small icons. Every other
            # full-screen panel had the room and was moved down instead (see the dice infusion
            # title, "Upgrade a Card", the dice shop panel). Restored by _show_map().
            Events.end_screen_hud_visibility.emit(false)



func _on_show_reward():
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats
    reward_scene.character_stats = character
    for i in Global.pending_card_rewards:
        reward_scene.add_card_reward()
    Global.pending_card_rewards = 1

func _on_debug_battle_button_pressed() -> void:
    Global.debug_battle_entry = true
    _change_view(BATTLE_SCENE)

# Slides the whole "visit the Dice Shop" tip so its arrow lands on the actual Dice Shop button
# in the top bar - it was authored pointing at the DECK button, one slot too far right.
#
# Measured from the live nodes rather than re-authored as a fixed offset: the tip and the button
# both live under the TopBar CanvasLayer, but the button's x comes from an HBoxContainer sort,
# so any future change to the bar's contents would silently break a hardcoded position. The
# PANEL moves, not the arrow - the arrow deliberately overhangs the panel's right edge, and
# moving it alone would drag it back over the panel body.
#
# Uses the arrow's transform (not position + size/2): it's rotated with a top-left pivot, so
# its visual centre is not where its rect says it is.
func _align_dice_shop_explanation() -> void:
    var arrow: Control = dice_shop_explanation_box.get_node_or_null("Arrow")
    var button_rect := dice_shop.get_global_rect()
    if not arrow or button_rect.size == Vector2.ZERO:
        return
    var arrow_rect: Rect2 = arrow.get_global_transform() * Rect2(Vector2.ZERO, arrow.size)
    if arrow_rect.size == Vector2.ZERO:
        return
    # Idempotent: once aligned the delta is 0, so re-showing the tip can't drift it.
    dice_shop_explanation_box.position.x += button_rect.get_center().x - arrow_rect.get_center().x


func _on_dice_shop_pressed() -> void:
    SFXPlayer.play(sfx_click)
    dice_shop_explanation_box.hide()
    if dice_shop_instance:
        dice_shop_instance.queue_free()
    dice_shop_instance = DICE_SHOP_SCENE.instantiate()
    $TopBar.add_child(dice_shop_instance)
    # Only when there is nothing else on screen. The dice shop is a floating panel that was
    # designed to sit over the map, and this used to call show_map() unconditionally - so
    # opening it from inside a room (campfire, treasure, event) revealed the map BEHIND the
    # room you were standing in. On the map itself the map is already shown, so this is a
    # no-op there; the only case it ever changed anything was the one it broke.
    if current_view.get_child_count() == 0:
        map.show_map()


# Closing the dice shop must ONLY close the dice shop. Its exit buttons used to emit
# show_map_requested / shop_exited, both of which run.gd routes to _show_map() - and
# _show_map() frees whatever is in current_view. So opening the dice shop at a campfire and
# closing it again destroyed the campfire and dumped the player back on the map, losing the
# rest/upgrade. Same for treasure, events and the card shop.
func _on_dice_shop_closed() -> void:
    if dice_shop_instance:
        dice_shop_instance.queue_free()
        dice_shop_instance = null
    
    
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


func _on_pause_button_pressed() -> void:
    pause_menu.toggle()


# Same stuck-tooltip guard as _open_map_consult(): pausing freezes mouse_exited on
# non-ALWAYS nodes, so a relic tooltip mid-hover would otherwise sit frozen on
# screen for as long as the pause menu is up (and after closing it, too).
func _on_pause_menu_opened() -> void:
    for relic_ui in relic_handler.relics.get_children():
        if relic_ui.has_method("_cleanup_tooltips"):
            relic_ui._cleanup_tooltips()
    # Map is PROCESS_MODE_ALWAYS on purpose (map consult needs it interactive while
    # the tree is paused), but that also means the pause menu's tree-pause does NOT
    # freeze it - map.gd polls Input in _process and handles raw _input, both of
    # which ignore the menu's full-screen dimmer entirely (they never go through
    # GUI), and room Area2Ds keep firing hover. Demote it to PAUSABLE while the
    # menu is up so the map underneath is truly inert; restored on close below.
    map.process_mode = Node.PROCESS_MODE_PAUSABLE


func _on_pause_menu_closed() -> void:
    map.process_mode = Node.PROCESS_MODE_ALWAYS


var _pause_tooltip: Node


func _on_pause_button_mouse_entered() -> void:
    pause_button.modulate = Color(1.18, 1.18, 1.18)
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(pause_button_hover_glow, "modulate:a", 1.0, 0.12)
    if is_instance_valid(_pause_tooltip):
        _pause_tooltip.queue_free()
    _pause_tooltip = IconTooltip.spawn_below(pause_button, "Settings")


func _on_pause_button_mouse_exited() -> void:
    pause_button.modulate = Color.WHITE
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(pause_button_hover_glow, "modulate:a", 0.0, 0.12)
    if is_instance_valid(_pause_tooltip):
        _pause_tooltip.queue_free()
        _pause_tooltip = null

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
    _hide_nested_canvas_layers(view)
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
    # No text label on the icon button (see run.tscn - now a plain TextureButton,
    # the scroll icon replaced the old "Map"/"Close Map" text button) - a warm
    # tint stands in for that state change instead.
    _update_map_icon_modulate()

func _close_map_consult() -> void:
    map_consult_mode = false
    get_tree().paused = false
    map.hide_map()
    if current_view.get_child_count() > 0:
        var view := current_view.get_child(0)
        view.show()
        _restore_nested_canvas_layers(view)
        _set_nested_cameras_enabled(view, true)
    _update_map_icon_modulate()

# Hover feedback for the map icon button - a gold outline (HoverGlow, run.tscn)
# fades in, plus a brightness bump layered on top of whichever base tint
# currently applies (map_consult_mode's warm "active" tint, or plain white),
# so hovering while the map is open doesn't fight with/override that state.
var _map_icon_hovering := false
var _map_tooltip: Node

func _on_consult_map_button_mouse_entered() -> void:
    _map_icon_hovering = true
    _update_map_icon_modulate()
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(consult_map_button_hover_glow, "modulate:a", 1.0, 0.12)
    if is_instance_valid(_map_tooltip):
        _map_tooltip.queue_free()
    _map_tooltip = IconTooltip.spawn_below(consult_map_button, "Map")

func _on_consult_map_button_mouse_exited() -> void:
    _map_icon_hovering = false
    _update_map_icon_modulate()
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(consult_map_button_hover_glow, "modulate:a", 0.0, 0.12)
    if is_instance_valid(_map_tooltip):
        _map_tooltip.queue_free()
        _map_tooltip = null

func _update_map_icon_modulate() -> void:
    var base := Color(1.35, 1.15, 0.65) if map_consult_mode else Color.WHITE
    # Brighten RGB only (not alpha - Color * float scales all 4 channels, which
    # would push alpha above 1 and make WHITE's hover state semi-meaningless).
    var target := Color(base.r * 1.2, base.g * 1.2, base.b * 1.2, 1.0) if _map_icon_hovering else base
    # Bound tween would otherwise be paused along with the rest of the tree
    # while consulting the map - but ConsultMapButton itself stays interactive
    # then (process_mode=ALWAYS in run.tscn), so its own feedback should too.
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(consult_map_button, "modulate", target, 0.1)

# See _open_map_consult() - a hidden view's own Camera2D (not a CanvasItem) keeps
# running/staying current unless explicitly disabled, same class of gotcha as
# _hide_nested_canvas_layers/_restore_nested_canvas_layers above but for cameras
# instead of CanvasLayers.
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
#
# Remembers each CanvasLayer's PRIOR visibility (rather than unconditionally
# forcing true on restore) - battle.tscn's own "Tooltip" CanvasLayer (the draw/
# discard pile hover tooltip, battle.gd::_show_pile_tooltip/_hide_pile_tooltip)
# is deliberately visible=false whenever no pile is being hovered. Blanket-
# forcing every CanvasLayer back to visible=true on map-consult close was
# resurrecting that tooltip with whatever placeholder/stale content it happened
# to hold, showing it stuck on screen even though nothing was actually hovered.
var _canvas_layer_prev_visibility: Dictionary = {}

func _hide_nested_canvas_layers(node: Node) -> void:
    for child in node.get_children():
        if child is CanvasLayer:
            _canvas_layer_prev_visibility[child] = child.visible
            child.visible = false
        _hide_nested_canvas_layers(child)

func _restore_nested_canvas_layers(node: Node) -> void:
    for child in node.get_children():
        if child is CanvasLayer:
            child.visible = _canvas_layer_prev_visibility.get(child, true)
        _restore_nested_canvas_layers(child)

func _on_stop_map_music() -> void:
    map_music.stop()


func _on_start_map_music() -> void:
    map_music.play()

func _on_check_if_can_purchase_dice() -> void:
    # null (no shop visited yet / empty selection) must read as "not affordable" - before,
    # the null case left the indicator and blink in whatever state they were last in.
    if Global.cheapest_dice_price != null and Global.gold >= Global.cheapest_dice_price:
        affordable_indicator.show()
        dice_shop.set_blinking(true)
    else:
        affordable_indicator.hide()
        dice_shop.set_blinking(false)
    map.refresh_affordable_badges()


# Run outlives every shop panel, so this is the listener that keeps the cached cheapest
# price honest when prices change while the dice-shop panel is CLOSED (the card-shop deal
# die escalates every price and emits this - that was the "badge says affordable at act 2
# start when it isn't" bug: the only other listener lived on the dead panel).
func _on_dice_price_changed() -> void:
    Global.refresh_cheapest_dice_price()
    _on_check_if_can_purchase_dice()

# New function to handle relic rewards from events
func _on_show_reward_with_relic(relic: Relic) -> void:
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats
    reward_scene.character_stats = character
    reward_scene.relic_handler = relic_handler
    reward_scene.add_relic_reward(relic)


# Same as _on_show_reward_with_relic, but also drops a claimable gold pill on
# the same screen (event_russian_dice.gd's dice-5 payout) - relic can be null
# (relic pool exhausted) if only gold is left to claim.
func _on_show_reward_with_relic_and_gold(relic: Relic, gold_amount: int) -> void:
    var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
    reward_scene.run_stats = stats
    reward_scene.character_stats = character
    reward_scene.relic_handler = relic_handler
    if relic:
        reward_scene.add_relic_reward(relic)
    if gold_amount > 0:
        reward_scene.add_gold_reward(gold_amount)


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
    "tutorial_on", "tutorial_fight", "tutorial_enemy_attack",
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
        "dice_infusions": Global.dice_infusions.duplicate(),
        "dice_inventory": Global.dice_inventory.duplicate(),
        "purchased_dice_counts": Global.purchased_dice_counts.duplicate(),
        "shop_initialized": Global.shop_initialized,
        "shop_dice_selection": Global.shop_dice_selection.duplicate(),
        "shop_dice_deal_index": Global.shop_dice_deal_index,
        "card_removals_bought": Global.card_removals_bought,
        "cheapest_dice_price": Global.cheapest_dice_price,
        "blue_rolls_this_run": Global.blue_dice_rolled_this_run,
        "run_screen_stats": {
            "dice_rolled": Global.run_stat_dice_rolled,
            "power_generated": Global.run_stat_power_generated,
            "biggest_hit": Global.run_stat_biggest_hit,
            "damage_taken": Global.run_stat_damage_taken,
            "cards_played": Global.run_stat_cards_played,
            "enemies_slain": Global.run_stat_enemies_slain,
            "highest_floor": Global.run_stat_highest_floor,
        },
        "tutorials": tutorials_out,
        "used_battles": used_battles_out,
        "event_pool_remaining": event_pool_out,
        "event_pool_initial": initial_event_pool_out,
        "run_stats": {
            "card_rewards": stats.card_rewards,
            "rare_weight": stats.rare_weight,
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
    # data.get() fallback: saves written before the rarity system (normal_weight/
    # support_weight keys, no rare_weight) fall back to the fresh RunStats.new() default
    # rather than KeyError-ing on load.
    stats.rare_weight = data["run_stats"].get("rare_weight", RunStats.BASE_RARE_WEIGHT)

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
    # .get with default: saves written before the infusion feature (2026-07-14) lack the key.
    Global.dice_infusions = data.get("dice_infusions", {})
    Global.purchased_dice_counts = data["purchased_dice_counts"]
    Global.shop_initialized = data["shop_initialized"]
    Global.shop_dice_selection = data["shop_dice_selection"]
    # .get with defaults: saves written before the shop rework (2026-07-23) lack these keys.
    Global.shop_dice_deal_index = data.get("shop_dice_deal_index", -1)
    Global.card_removals_bought = data.get("card_removals_bought", 0)
    # Re-derive instead of trusting the saved cache: selection + purchase counts are
    # already restored above, the save's value can be stale (pre-fix saves), and saves
    # written before this key existed would hard-fail a direct index here.
    Global.refresh_cheapest_dice_price()
    # .get with default: saves written before the achievement system lack the key.
    Global.blue_dice_rolled_this_run = data.get("blue_rolls_this_run", 0)

    # .get with defaults: saves written before the end-screen stats (2026-07-21) lack the key.
    var screen_stats: Dictionary = data.get("run_screen_stats", {})
    Global.run_stat_dice_rolled = screen_stats.get("dice_rolled", 0)
    Global.run_stat_power_generated = screen_stats.get("power_generated", 0)
    Global.run_stat_biggest_hit = screen_stats.get("biggest_hit", 0)
    Global.run_stat_damage_taken = screen_stats.get("damage_taken", 0)
    Global.run_stat_cards_played = screen_stats.get("cards_played", 0)
    Global.run_stat_enemies_slain = screen_stats.get("enemies_slain", 0)
    Global.run_stat_highest_floor = screen_stats.get("highest_floor", 1)

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
    dice_shop.set_available(true)
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
