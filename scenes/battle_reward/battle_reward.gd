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

# Secondary keyword tooltips (e.g. "Scout" next to a relic's own description) - this screen
# never had these at all before, unlike relic_ui.gd's hover (a separate, simpler tooltip system
# for reward buttons specifically). Mirrors relic_ui.gd's pattern.
const TOOLTIP_OFFSET_X = 8
const TOOLTIP_HEIGHT = 108
const TOOLTIP_SPACING = 1
var relic_tooltip_instances_tags: Array = []
var _relic_hover_id := 0

var warning_dismissed := false

@export var run_stats: RunStats
@export var character_stats: CharacterStats
@export var relic_handler: RelicHandler

@onready var rewards: VBoxContainer = %Rewards
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

@onready var warning_panel: Panel = $WarningPanel
@onready var confirm_button: Button = $WarningPanel/ConfirmButton
@onready var gg_panel: Panel = $GGPanel
@onready var gg_label_title: Label = $GGPanel/GGLabelTitle
@onready var gg_label_text: RichTextLabel = $GGPanel/GGLabelText
@onready var join_discord_control: Control = $GGPanel/JoinDiscordControl
@onready var continue_act_2_button: Button = $GGPanel/ContinueAct2Button


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
    # Show GG panel if a boss was defeated: after the act-1 boss it becomes the
    # act-transition panel (retitled + Continue button), after the act-2 boss it
    # stays the original final "thanks for playing" panel from the .tscn.
    if Global.is_final_boss_fight:
        if Global.current_act == 1:
            _setup_act_transition_panel()
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


# Tooltips live under get_tree().root, not this node - free them explicitly whenever this
# screen itself is torn down, otherwise a still-hovered tooltip can leak into whatever screen
# comes next (same bug class as relic_ui.gd's, see its _exit_tree() comment).
func _exit_tree() -> void:
    _cleanup_relic_tooltips()

func _cleanup_relic_tooltips() -> void:
    if relic_tooltip_instance and is_instance_valid(relic_tooltip_instance):
        relic_tooltip_instance.queue_free()
        relic_tooltip_instance = null
    for tooltip in relic_tooltip_instances_tags:
        if tooltip and is_instance_valid(tooltip):
            tooltip.queue_free()
    relic_tooltip_instances_tags.clear()

# Called when mouse enters a relic reward button
func _on_relic_reward_mouse_entered(relic: Relic, button: Control) -> void:
    _cleanup_relic_tooltips()
    _relic_hover_id += 1
    var my_id := _relic_hover_id

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

    # Secondary keyword tooltips (e.g. "Scout") - same tags + tag-free dice-type detection as
    # relic_ui.gd, just never wired up on this screen before.
    var tags_to_show: Array = []
    if relic.tags != "":
        for tag in relic.tags.split(","):
            var trimmed: String = tag.strip_edges()
            if trimmed != "":
                tags_to_show.append(trimmed)
    for dice_keyword in KeywordColorizer.find_dice_keywords_in_text(relic.tooltip):
        if not tags_to_show.has(dice_keyword):
            tags_to_show.append(dice_keyword)

    if tags_to_show.is_empty():
        return

    # Wait a frame so the main tooltip panel has its real size before positioning off of it
    # (same gotcha relic_ui.gd already worked around).
    await get_tree().create_timer(0.5).timeout
    if my_id != _relic_hover_id:
        return

    var total_height = (tags_to_show.size() * TOOLTIP_HEIGHT) + ((tags_to_show.size() - 1) * TOOLTIP_SPACING)
    var center_y = pos.y + (tooltip_panel.size.y / 2.0)
    var start_y = center_y - (total_height / 2.0)

    var screen_height = get_viewport_rect().size.y
    if start_y + total_height > screen_height - 20:
        start_y = screen_height - total_height - 20
    if start_y < 20:
        start_y = 20

    var base_pos = Vector2(pos.x + tooltip_panel.size.x + TOOLTIP_OFFSET_X, start_y)
    var captured_id := my_id

    for i in range(tags_to_show.size()):
        var tag_tooltip = TooltipScene.instantiate()
        get_tree().root.add_child(tag_tooltip)
        var tag_panel = tag_tooltip.get_node("Tooltip")
        tag_panel.get_tooltip_content(tags_to_show[i])
        var tag_pos = (base_pos + Vector2(0, i * (TOOLTIP_HEIGHT + TOOLTIP_SPACING))).round()
        tag_panel.show_tooltip(tag_pos)
        relic_tooltip_instances_tags.append(tag_tooltip)

    get_tree().create_timer(6.0).timeout.connect(func():
        if captured_id == _relic_hover_id:
            _cleanup_relic_tooltips()
    )

# Called when mouse exits the relic reward button
func _on_relic_reward_mouse_exited() -> void:
    _relic_hover_id += 1
    _cleanup_relic_tooltips()

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
    Events.gold_changed.emit()


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


# Act-1-complete variant of the GG panel: same panel, retitled, Discord control
# swapped out for the Continue button. The actual act switch is armed in run.gd
# (_on_battle_won) and fires on the next return to the map - this button only
# dismisses the panel, so the boss gold/card rewards underneath can still be
# collected before leaving.
func _setup_act_transition_panel() -> void:
    gg_label_title.text = "Act 1 Complete!"
    gg_label_text.text = "[color=pink]Looks like you know how to roll Dice![/color] But the dungeon runs deeper...

Gather your rewards, then continue when you're ready.

[color=gold]You will be fully healed upon entering Act 2.[/color]
"
    join_discord_control.hide()
    continue_act_2_button.show()


func _on_continue_act_2_button_pressed() -> void:
    SFXPlayer.play(Global.sfx_click)
    gg_panel.hide()
