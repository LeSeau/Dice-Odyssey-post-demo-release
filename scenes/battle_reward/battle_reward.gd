class_name BattleReward
extends Control

#enum Type {GOLD, NEW_CARD, RELIC}

const CARD_REWARDS = preload("res://scenes/ui/card_rewards.tscn")
const REWARD_BUTTON = preload("res://scenes/ui/reward_button.tscn")
const GOLD_ICON := preload("res://gold_icon_v2.png")
const GOLD_TEXT := "%s gold"
const CARD_ICON := preload("res://card_cover_ok.png")
const CARD_TEXT := "Add New Card"

var relic_tooltip_instance: CanvasLayer
const TooltipScene = preload("res://scenes/ui/tooltip.tscn")

var warning_dismissed := false

@export var run_stats: RunStats
@export var character_stats: CharacterStats
@export var relic_handler: RelicHandler

@onready var rewards: VBoxContainer = %Rewards
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

@onready var warning_panel: Panel = $WarningPanel
@onready var confirm_button: Button = $WarningPanel/ConfirmButton
@onready var gg_panel: Panel = $GGPanel


var card_reward_total_weight := 0.0
var card_rarity_weights := {
    Card.Rarity.NORMAL: 0.0,
    Card.Rarity.SUPPORT: 0.0}
    

func _ready() -> void:
    for node: Node in rewards.get_children():
        node.queue_free()
        
    run_stats = RunStats.new()
    Events.gold_changed.connect(func():print("gold:%s" % Global.gold))
    
    character_stats = preload("res://characters/warrior/warrior.tres").create_instance()

    audio_player.stream = load("res://success.mp3")
    audio_player.play()
    # Show GG panel if final boss was defeated
    if Global.is_final_boss_fight:
        gg_panel.show()
        Global.is_final_boss_fight = false
    else:
        gg_panel.hide()

func add_gold_reward(amount: int) -> void:
    var gold_reward := REWARD_BUTTON.instantiate() as RewardButton
    gold_reward.custom_minimum_size.y = 70
    gold_reward.reward_icon = GOLD_ICON
    gold_reward.reward_text = GOLD_TEXT % amount
    gold_reward.pressed.connect(on_gold_reward_taken.bind(amount))  
    rewards.add_child.call_deferred(gold_reward)

func add_card_reward() -> void:
    var card_reward := REWARD_BUTTON.instantiate() as RewardButton
    card_reward.custom_minimum_size.y = 70
    card_reward.reward_icon = CARD_ICON
    card_reward.reward_text = CARD_TEXT
    card_reward.pressed.connect(_show_card_rewards)
    rewards.add_child.call_deferred(card_reward)
    
func add_relic_reward(relic: Relic) -> void:
    var relic_reward := REWARD_BUTTON.instantiate() as RewardButton
    relic_reward.reward_icon = relic.icon
    relic_reward.reward_text = relic.relic_name
    
    # Connect hover signals to show/hide tooltip
    relic_reward.mouse_entered.connect(_on_relic_reward_mouse_entered.bind(relic, relic_reward))
    relic_reward.mouse_exited.connect(_on_relic_reward_mouse_exited)
    
    relic_reward.pressed.connect(_on_relic_reward_taken.bind(relic))
    rewards.add_child.call_deferred(relic_reward)


# Called when mouse enters a relic reward button
func _on_relic_reward_mouse_entered(relic: Relic, button: Control) -> void:
    if relic_tooltip_instance and is_instance_valid(relic_tooltip_instance):
        return # Already showing

    relic_tooltip_instance = TooltipScene.instantiate()
    get_tree().root.add_child(relic_tooltip_instance)

    # Get the Tooltip panel child
    var tooltip_panel = relic_tooltip_instance.get_node("Tooltip")
    
    # Set tooltip title + text
    tooltip_panel.tooltip_title.text = "[color=gold][b]%s[/b][/color]" % relic.relic_name
    tooltip_panel.tooltip_label.text = relic.get_colorized_description(relic.tooltip)

    # Position tooltip to the right of the button
    var pos = button.get_global_position() + Vector2(button.get_size().x + 8, 0)
    tooltip_panel.show_tooltip(pos)

# Called when mouse exits the relic reward button
func _on_relic_reward_mouse_exited() -> void:
    if relic_tooltip_instance and is_instance_valid(relic_tooltip_instance):
        relic_tooltip_instance.queue_free()
        relic_tooltip_instance = null
    
func _show_card_rewards() -> void:
    if not run_stats or not character_stats:
        return

    var card_rewards := CARD_REWARDS.instantiate() as CardRewards
    add_child(card_rewards)
    card_rewards.card_reward_selected.connect(_on_card_reward_taken)

    var card_reward_array: Array[Card] = []
    var available_cards: Array[Card] = character_stats.draftable_cards.cards.duplicate(true)

    for i in range(3):
        _setup_card_chances()
        var roll := randf_range(0.0, card_reward_total_weight)
        var cumulative := 0.0

        for rarity: Card.Rarity in card_rarity_weights:
            cumulative += card_rarity_weights[rarity]
            if roll <= cumulative:
                _modify_weights(rarity)
                var picked_card := _get_random_available_card(available_cards, rarity)
                if picked_card:
                    card_reward_array.append(picked_card)
                    available_cards.erase(picked_card)
                break

    card_rewards.rewards = card_reward_array
    card_rewards.show()

    
func _setup_card_chances() -> void:
    card_reward_total_weight = run_stats.normal_weight + run_stats.support_weight
    card_rarity_weights[Card.Rarity.NORMAL] = run_stats.normal_weight
    card_rarity_weights[Card.Rarity.SUPPORT] = run_stats.support_weight


func _modify_weights(rarity_rolled: Card.Rarity) -> void:
    if rarity_rolled == Card.Rarity.SUPPORT:
        run_stats.support_weight = RunStats.BASE_SUPPORT_WEIGHT
    else:
        run_stats.support_weight = clampf (run_stats.support_weight + 0.3, run_stats.BASE_SUPPORT_WEIGHT, 5.0)
    

func _get_random_available_card(available_cards: Array[Card], with_rarity: Card.Rarity) -> Card:
    var all_possible_cards := available_cards.filter(
        func(card: Card):
            return card.rarity == with_rarity
    )
    
    all_possible_cards.shuffle()
    return all_possible_cards.pick_random()
 
func _on_card_reward_taken(card: Card) -> void:
    if not character_stats or not card:
        return
    print("reward taken")
    character_stats.deck.add_card(card)
    SFXPlayer.play(Global.sfx_click)
    
func _on_relic_reward_taken(relic: Relic) -> void:
    if not relic or not relic_handler:
        return
        
    relic_handler.add_relic(relic)  
 
func on_gold_reward_taken(amount: int) -> void:
    SFXPlayer.play(Global.sfx_gold_pickup)
    Global.gold += amount  # <- This uses Global system directly
    if run_stats:
        run_stats.gold = Global.gold  # Sync RunStats to match


func _on_back_button_pressed() -> void:
    # Check if there are unclaimed rewards and warning hasn't been dismissed
    if _has_unclaimed_rewards() and not warning_dismissed:
        _show_warning()
    else:
        _exit_battle_rewards()

func _has_unclaimed_rewards() -> bool:
    # Check if any reward buttons still exist (unclaimed rewards)
    return rewards.get_child_count() > 0

func _show_warning() -> void:
    if warning_panel:
        warning_panel.show()
        SFXPlayer.play(Global.sfx_click)

func _exit_battle_rewards() -> void:
    Events.battle_reward_exited.emit()
    Events.start_map_music.emit()


func _on_confirm_button_pressed() -> void:
    warning_panel.hide()
    warning_dismissed = true
    SFXPlayer.play(Global.sfx_click)


func _on_join_discord_button_pressed() -> void:
    OS.shell_open("https://discord.gg/fah8A2qQx2")
