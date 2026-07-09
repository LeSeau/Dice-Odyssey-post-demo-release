extends Control

@onready var roll_golden_dice: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/RollGoldenDice
@onready var quit: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit
@onready var dice_panel: Panel = $DicePanel
@onready var button: Button = $DicePanel/DiceDisplay/Button
@onready var test: Button = $DicePanel/DiceDisplay/Test
@onready var roll_dice: Button = $DicePanel/DiceDisplay/RollDice
@onready var dice_display: TextureRect = $DicePanel/DiceDisplay
@onready var reward_panel: Panel = $DicePanel/RewardPanel
@onready var continue_button: Button = $DicePanel/ContinueButton
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
@onready var stop_button: Button = $DicePanel/StopButton


@onready var sad_goblin: TextureRect = $DicePanel/SadGoblin
@onready var audio_listener_2d: AudioStreamPlayer2D = $AudioListener2D

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


func _on_quit_pressed() -> void:
    Events.event_exited.emit()

func _on_continue_button_pressed() -> void:
    Events.event_exited.emit()

func _on_roll_golden_dice_pressed() -> void:
    print("opening golden dice box")
    dice_panel.show()

func _on_button_pressed() -> void:
    print("rolling golden dice")
    
func update_rewards_recap() -> void:
    var text := "Rewards: " + str(gold_reward) + " Gold"
    if heal_reward > 0:
        text += ", " + str(heal_reward) + " HP"
    rewards_recap_label.text = "[center]" + text + "[/center]"

func _on_roll_dice_pressed() -> void:
    var number_of_outcomes = faces.size()
    
    # Step 1: Roll several times quickly
    for i in range(10):
        var temp_roll = randi() % number_of_outcomes
        dice_display.texture = faces[temp_roll]
        await get_tree().create_timer(0.05).timeout  # wait 0.05 seconds between face changes
    
    # Step 2: Final roll
    var final_roll = randi() % number_of_outcomes
    dice_display.texture = faces[final_roll]

    var roll_result = final_roll + 1  # make it 1 to 6

    # Step 3: Wait 0.5 seconds, then show reward panel
    await get_tree().create_timer(0.5).timeout
    var purchase_sound = preload("res://sounds/purchase.mp3")
    audio_listener_2d.stream = purchase_sound
    audio_listener_2d.play()

    if roll_result!= 1:
        reward_panel.show()
        var gold_reward = roll_result * 10
        Global.gold += gold_reward 
        Events.gold_changed.emit()

        # 🔥 Build the reward text manually
        reward_label.text = "[center]You won [color=yellow]" + str(gold_reward) + " Gold[/color]![/center]"

        # Step 4: Wait another 1.5 seconds, show sad goblin
        await get_tree().create_timer(1.5).timeout
        continue_button.show()

        var kamikaze_fail = preload("res://sounds/kamikazefail.mp3")
        audio_listener_2d.stream = kamikaze_fail
        audio_listener_2d.play()
    else:
        reward_panel.show()
        reward_label.text = "[center]Thank you![/center]"
        await get_tree().create_timer(1.5).timeout
        continue_button.show()

        sad_goblin.texture = preload("res://events_gold_dice.png")
        var kamikaze_fail = preload("res://sounds/kamikazefail.mp3")
        audio_listener_2d.stream = kamikaze_fail
        audio_listener_2d.play()
        Global.gold = 0 
        Events.gold_changed.emit()
        

func _on_test_pressed() -> void:
    print("pressed test")


func _on_play_button_pressed() -> void:
    dice_panel.show()


func _on_roll_dice_1_pressed() -> void:

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
        stop_button.disabled = false
        roll_dice_1.disabled = true
        reward_1.set("theme_override_styles/panel", REWARD_STYLEBOX)
        gold_reward+=15
        update_rewards_recap()
    else:
        await get_tree().create_timer(1).timeout
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_roll_dice_2_pressed() -> void:
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
        roll_dice_2.disabled = true
        reward_2.set("theme_override_styles/panel", REWARD_STYLEBOX)
        heal_reward+=5
        update_rewards_recap()
    else:
        await get_tree().create_timer(1).timeout
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_loser_exit_button_pressed() -> void:
   Events.event_exited.emit()


func _on_winner_exit_button_pressed() -> void:
    Global.gold += gold_reward
    character_stats.health+= heal_reward
    Events.gold_changed.emit()
    Events.hp_changed.emit()
    Events.event_exited.emit()


func _on_roll_dice_3_pressed() -> void:

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
        roll_dice_3.disabled = true
        reward_3.set("theme_override_styles/panel", REWARD_STYLEBOX)
        gold_reward+=30
        update_rewards_recap()
    else:
        await get_tree().create_timer(1).timeout
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_roll_dice_4_pressed() -> void:
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
        roll_dice_4.disabled = true
        reward_4.set("theme_override_styles/panel", REWARD_STYLEBOX)
        heal_reward+=10
        update_rewards_recap()
    else:
        await get_tree().create_timer(1).timeout
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_roll_dice_5_pressed() -> void:
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
        heal_reward+=30
        update_rewards_recap()
        winner_panel.show()
    else:
        await get_tree().create_timer(1).timeout
        loser_panel.show()
        var laugh_sound = preload("res://laughsound.mp3")
        audio_listener_2d.stream = laugh_sound
        audio_listener_2d.play()


func _on_stop_button_pressed() -> void:
    winner_panel.show()
