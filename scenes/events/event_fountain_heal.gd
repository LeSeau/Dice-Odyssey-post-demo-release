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

@onready var sad_goblin: TextureRect = $DicePanel/SadGoblin
@onready var audio_listener_2d: AudioStreamPlayer2D = $AudioListener2D

var character_stats: CharacterStats
var run_stats: RunStats

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _on_quit_pressed() -> void:
    Events.event_exited.emit()

func _on_continue_button_pressed() -> void:
    Events.event_exited.emit()



func _on_button_pressed() -> void:
    print("rolling golden dice")

func _on_roll_dice_pressed() -> void:
    # Guard against spam-clicking while the roll animation/reward await chain
    # below is still running - Button.disabled blocks further "pressed"
    # signals immediately, unlike a script-side flag which could still race
    # with a click landing in the same frame.
    if roll_dice.disabled:
        return
    roll_dice.disabled = true

    print("opening golden dice box")
    dice_panel.show()

    var faces = [
        load("res://assets/images/blue1.png"),
        load("res://assets/images/blue2.png"),
        load("res://assets/images/blue3.png"),
        load("res://assets/images/blue4.png"),
        load("res://assets/images/blue5.png"),
        load("res://assets/images/blue6.png")
    ]
    
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

    if roll_result!= 0:
        reward_panel.show()
        var health_reward = roll_result * 5
        # character_stats should always be set by run.gd's setup() call on entering
        # this event - guarding here anyway since it crashed the whole game once
        # with no other clue than "health on Nil"; this at least keeps the event
        # from hard-crashing and leaves a trail if it happens again.
        if character_stats == null:
            push_error("event_fountain_heal: character_stats is null, skipping heal")
        else:
            character_stats.health += health_reward
            Events.hp_changed.emit()

        # 🔥 Build the reward text manually
        reward_label.text = "[center]You won [color=green]" + str(health_reward) + " Health[/color]![/center]"

        # Step 4: Wait another 1.5 seconds, show sad goblin
        await get_tree().create_timer(1.5).timeout
        continue_button.show()
        var fountain_heal = preload("res://sounds/fountainheal.wav")
        audio_listener_2d.stream = fountain_heal
        audio_listener_2d.play()

        

func _on_test_pressed() -> void:
    print("pressed test")


func _on_roll_healing_dice_pressed() -> void:
    print("opening golden dice box")
    dice_panel.show()
