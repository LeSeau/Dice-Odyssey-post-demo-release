extends Control

@export var treasure_relic_pool: RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

@onready var quit: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit
@onready var dice_panel: Panel = $DicePanel
@onready var reward_panel: Panel = $DicePanel/RewardPanel
@onready var reward_label: RichTextLabel = $DicePanel/RewardPanel/RewardLabel
@onready var dice_display_1: TextureRect = $DicePanel/HBoxContainer/Dice1/DiceDisplay1
@onready var dice_display_2: TextureRect = $DicePanel/HBoxContainer/Dice2/DiceDisplay2
@onready var dice_display_3: TextureRect = $DicePanel/HBoxContainer/Dice3/DiceDisplay3
@onready var dice_display_4: TextureRect = $DicePanel/HBoxContainer/Dice4/DiceDisplay4
@onready var dice_display_5: TextureRect = $DicePanel/HBoxContainer/Dice5/DiceDisplay5


@onready var roll_dice_2: Button = $DicePanel/HBoxContainer/Dice2/DiceDisplay2/RollDice2
@onready var roll_dice_3: Button = $DicePanel/HBoxContainer/Dice3/DiceDisplay3/RollDice3
@onready var roll_dice_4: Button = $DicePanel/HBoxContainer/Dice4/DiceDisplay4/RollDice4
@onready var roll_dice_5: Button = $DicePanel/HBoxContainer/Dice5/DiceDisplay5/RollDice5
@onready var roll_dice_1: Button = $DicePanel/HBoxContainer/Dice1/DiceDisplay1/RollDice1

@onready var reward_1: Panel = $DicePanel/HBoxContainer/Dice1/Reward1
@onready var reward_2: Panel = $DicePanel/HBoxContainer/Dice2/Reward2
@onready var reward_3: Panel = $DicePanel/HBoxContainer/Dice3/Reward3
@onready var reward_4: Panel = $DicePanel/HBoxContainer/Dice4/Reward4
@onready var reward_5: Panel = $DicePanel/HBoxContainer/Dice5/Reward5
@onready var rewards_recap_label: RichTextLabel = $DicePanel/RewardsRecap/RewardsRecapLabel
@onready var loser_panel: Panel = $DicePanel/LoserPanel
@onready var winner_panel: Panel = $DicePanel/WinnerPanel
@onready var win_label: RichTextLabel = $DicePanel/WinnerPanel/WinLabel
@onready var stop_button: Button = $DicePanel/StopButton

@onready var audio_listener_2d: AudioStreamPlayer2D = $AudioListener2D

# Dice columns in play order, so a locked one can be dimmed as a whole (chip +
# die + ROLL plate) - the row is 5 identical columns and nothing else says which
# one is live.
@onready var dice_columns: Array[Node] = [
    $DicePanel/HBoxContainer/Dice1,
    $DicePanel/HBoxContainer/Dice2,
    $DicePanel/HBoxContainer/Dice3,
    $DicePanel/HBoxContainer/Dice4,
    $DicePanel/HBoxContainer/Dice5,
]

const COLUMN_LOCKED_TINT := Color(0.6, 0.6, 0.64, 1)
const COLUMN_LIVE_TINT := Color(1, 1, 1, 1)

const MODAL_TEXT := preload("res://scenes/events/event_modal_text.gd")
const REWARD_STYLEBOX := preload("res://reward_theme.tres")
var gold_reward = 0
var heal_reward = 0


var faces = [
        load("res://assets/images/blue1.png"),
        load("res://assets/images/blue2.png"),
        load("res://assets/images/blue3.png"),
        load("res://assets/images/blue4.png"),
        load("res://assets/images/blue5.png"),
        load("res://assets/images/blue6.png")
    ]


var character_stats: CharacterStats
var run_stats: RunStats

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats

func _ready() -> void:
    var entrance_sound = preload("res://sounds/openshopsound.wav")
    audio_listener_2d.stream = entrance_sound
    audio_listener_2d.play()
    roll_dice_2.disabled=true
    roll_dice_3.disabled=true
    roll_dice_4.disabled=true
    roll_dice_5.disabled=true
    stop_button.disabled=true
    for i in range(1, dice_columns.size()):
        _set_column_live(i, false)
    dice_panel.visibility_changed.connect(_recenter_modal_text)

# The chip / recap / result labels are BBCode, and RichTextLabel has no vertical
# alignment, so they need centring by hand. Done on show rather than in _ready:
# the chips live in nested containers, which only sort deferred, so their bands
# still measure 0 the frame _ready runs.
func _recenter_modal_text() -> void:
    if not dice_panel.visible:
        return
    await get_tree().process_frame
    MODAL_TEXT.center_labels(dice_panel)



# 0-based index into dice_columns.
func _set_column_live(index: int, live: bool) -> void:
    if index < 0 or index >= dice_columns.size():
        return
    dice_columns[index].modulate = COLUMN_LIVE_TINT if live else COLUMN_LOCKED_TINT


func _on_quit_pressed() -> void:
    Events.event_exited.emit()

func _on_continue_button_pressed() -> void:
    Events.event_exited.emit()

func update_rewards_recap() -> void:
    var text := "Rewards: " + str(gold_reward) + " Gold"
    if heal_reward > 0:
        text += ", " + str(heal_reward) + " HP"
    rewards_recap_label.text = "[center]" + text + "[/center]"
    MODAL_TEXT.center_label(rewards_recap_label)


func _on_play_button_pressed() -> void:
    dice_panel.show()


func _on_roll_dice_1_pressed() -> void:
    # Guard against spam-clicking the same die while its roll/reward await
    # chain is still running (each _on_roll_dice_N_pressed only disables its
    # own button on SUCCESS, further down - not immediately on click).
    if roll_dice_1.disabled:
        return
    roll_dice_1.disabled = true

    var number_of_outcomes = faces.size()
    
    # Step 1: Roll several times quickly
    for i in range(10):
        var temp_roll = randi() % number_of_outcomes
        dice_display_1.texture = faces[temp_roll]
        await get_tree().create_timer(0.05).timeout  # wait 0.05 seconds between face changes
    
    # Step 2: Final roll
    var final_roll = randi() % number_of_outcomes
    dice_display_1.texture = faces[final_roll]

    var roll_result = final_roll + 1  # make it 1 to 6

    if roll_result != 1:
        # Step 3: Wait 0.5 seconds, then show reward panel
        await get_tree().create_timer(0.5).timeout
        var purchase_sound = preload("res://sounds/purchase.mp3")
        audio_listener_2d.stream = purchase_sound
        audio_listener_2d.play()
        roll_dice_2.disabled = false
        _set_column_live(1, true)
        stop_button.disabled = false
        roll_dice_1.disabled = true
        reward_1.set("theme_override_styles/panel", REWARD_STYLEBOX)
        gold_reward+=15
        update_rewards_recap()
    else:
        await get_tree().create_timer(1).timeout
        stop_button.disabled = true
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_roll_dice_2_pressed() -> void:
    if roll_dice_2.disabled:
        return
    roll_dice_2.disabled = true

    var number_of_outcomes = faces.size()
    
    # Step 1: Roll several times quickly
    for i in range(10):
        var temp_roll = randi() % number_of_outcomes
        dice_display_2.texture = faces[temp_roll]
        await get_tree().create_timer(0.05).timeout  # wait 0.05 seconds between face changes
    
    # Step 2: Final roll
    var final_roll = randi() % number_of_outcomes
    dice_display_2.texture = faces[final_roll]

    var roll_result = final_roll + 1  # make it 1 to 6

    if roll_result !=1: 
        # Step 3: Wait 0.5 seconds, then show reward panel
        await get_tree().create_timer(0.5).timeout
        var purchase_sound = preload("res://sounds/purchase.mp3")
        audio_listener_2d.stream = purchase_sound
        audio_listener_2d.play()
        roll_dice_3.disabled = false
        _set_column_live(2, true)
        roll_dice_2.disabled = true
        reward_2.set("theme_override_styles/panel", REWARD_STYLEBOX)
        heal_reward+=5
        update_rewards_recap()
    else:
        await get_tree().create_timer(1).timeout
        stop_button.disabled = true
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_loser_exit_button_pressed() -> void:
   Events.event_exited.emit()


func _on_winner_exit_button_pressed() -> void:
    Global.gold += gold_reward
    # character_stats should always be set by run.gd's setup() call on entering
    # this event - guarding here anyway, same pattern as event_fountain_heal.gd's
    # "health on Nil" crash (only seen so far when running this scene standalone
    # in the editor, not through a normal run).
    if character_stats == null:
        push_error("event_russian_dice: character_stats is null, skipping heal reward")
    else:
        character_stats.health += heal_reward
        Events.hp_changed.emit()
    Events.gold_changed.emit()
    Events.event_exited.emit()


func _on_roll_dice_3_pressed() -> void:
    if roll_dice_3.disabled:
        return
    roll_dice_3.disabled = true

    var number_of_outcomes = faces.size()
    
    # Step 1: Roll several times quickly
    for i in range(10):
        var temp_roll = randi() % number_of_outcomes
        dice_display_3.texture = faces[temp_roll]
        await get_tree().create_timer(0.05).timeout  # wait 0.05 seconds between face changes
    
    # Step 2: Final roll
    var final_roll = randi() % number_of_outcomes
    dice_display_3.texture = faces[final_roll]

    var roll_result = final_roll + 1  # make it 1 to 6

    if roll_result != 1:
        # Step 3: Wait 0.5 seconds, then show reward panel
        await get_tree().create_timer(0.5).timeout
        var purchase_sound = preload("res://sounds/purchase.mp3")
        audio_listener_2d.stream = purchase_sound
        audio_listener_2d.play()
        roll_dice_4.disabled = false
        _set_column_live(3, true)
        roll_dice_3.disabled = true
        reward_3.set("theme_override_styles/panel", REWARD_STYLEBOX)
        gold_reward+=30
        update_rewards_recap()
    else:
        await get_tree().create_timer(1).timeout
        stop_button.disabled = true
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_roll_dice_4_pressed() -> void:
    if roll_dice_4.disabled:
        return
    roll_dice_4.disabled = true

    var number_of_outcomes = faces.size()
    
    # Step 1: Roll several times quickly
    for i in range(10):
        var temp_roll = randi() % number_of_outcomes
        dice_display_4.texture = faces[temp_roll]
        await get_tree().create_timer(0.05).timeout  # wait 0.05 seconds between face changes
    
    # Step 2: Final roll
    var final_roll = randi() % number_of_outcomes
    dice_display_4.texture = faces[final_roll]

    var roll_result = final_roll + 1  # make it 1 to 6

    if roll_result != 1:
        # Step 3: Wait 0.5 seconds, then show reward panel
        await get_tree().create_timer(0.5).timeout
        var purchase_sound = preload("res://sounds/purchase.mp3")
        audio_listener_2d.stream = purchase_sound
        audio_listener_2d.play()
        roll_dice_5.disabled = false
        _set_column_live(4, true)
        roll_dice_4.disabled = true
        reward_4.set("theme_override_styles/panel", REWARD_STYLEBOX)
        heal_reward+=10
        update_rewards_recap()
    else:
        await get_tree().create_timer(1).timeout
        stop_button.disabled = true
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_roll_dice_5_pressed() -> void:
    if roll_dice_5.disabled:
        return
    roll_dice_5.disabled = true

    var number_of_outcomes = faces.size()
    
    # Step 1: Roll several times quickly
    for i in range(10):
        var temp_roll = randi() % number_of_outcomes
        dice_display_5.texture = faces[temp_roll]
        await get_tree().create_timer(0.05).timeout  # wait 0.05 seconds between face changes
    
    # Step 2: Final roll
    var final_roll = randi() % number_of_outcomes
    dice_display_5.texture = faces[final_roll]

    var roll_result = final_roll + 1  # make it 1 to 6

    if roll_result != 1:
        # Step 3: Wait 0.5 seconds, then show reward panel
        await get_tree().create_timer(0.5).timeout
        var purchase_sound = preload("res://sounds/purchase.mp3")
        audio_listener_2d.stream = purchase_sound
        audio_listener_2d.play()
        roll_dice_5.disabled = true
        reward_5.set("theme_override_styles/panel", REWARD_STYLEBOX)
        await get_tree().create_timer(0.6).timeout
        _finish_with_relic_reward()
    else:
        await get_tree().create_timer(1).timeout
        stop_button.disabled = true
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


# The 5th dice is a full clean sweep - its payout is a relic, not gold/HP, so
# we settle the HP banked from dice 1-4 directly (no reward-screen equivalent
# for HP) and hand the banked gold off to the reward screen as a claimable
# pill next to the relic, instead of adding it to Global.gold here - doing
# both would double-count it once the player claims the pill.
func _finish_with_relic_reward() -> void:
    if character_stats == null:
        push_error("event_russian_dice: character_stats is null, skipping heal reward")
    else:
        character_stats.health += heal_reward
        Events.hp_changed.emit()
    var relic := treasure_relic_pool.get_random_relic(char_stats, relic_handler)
    Events.show_reward_with_relic_and_gold.emit(relic, gold_reward)


func _on_stop_button_pressed() -> void:
    # The card sits on top of the recap band, so it has to restate the haul.
    var parts: Array[String] = []
    if gold_reward > 0:
        parts.append("[color=#eeb52a]%d Gold[/color]" % gold_reward)
    if heal_reward > 0:
        parts.append("[color=#5ad16b]%d HP[/color]" % heal_reward)
    if parts.is_empty():
        win_label.text = "[center]You walk away with nothing.[/center]"
    else:
        win_label.text = "[center]You walk away with " + " and ".join(parts) + ".[/center]"
    MODAL_TEXT.center_label(win_label)
    winner_panel.show()
