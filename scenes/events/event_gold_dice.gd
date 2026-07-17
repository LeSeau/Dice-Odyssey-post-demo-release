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

func _on_quit_pressed() -> void:
    Events.event_exited.emit()

func _on_continue_button_pressed() -> void:
    Events.event_exited.emit()

func _on_roll_golden_dice_pressed() -> void:
    print("opening golden dice box")
    dice_panel.show()

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

    print("rolling event dice")

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

    if roll_result!= 1:
        reward_panel.show()
        var gold_reward = roll_result * 20
        Global.gold += gold_reward 
        Events.gold_changed.emit()

        # 🔥 Build the reward text manually
        reward_label.text = "[center]You won [color=gold]" + str(gold_reward) + " Gold[/color]![/center]"

        # Step 4: Wait another 1.5 seconds, show sad goblin
        await get_tree().create_timer(1.5).timeout
        continue_button.show()
        sad_goblin.show()
        var kamikaze_fail = preload("res://sounds/kamikazefail.mp3")
        audio_listener_2d.stream = kamikaze_fail
        audio_listener_2d.play()
    else:
        reward_panel.show()
        reward_label.text = "[center]Thank you![/center]"
        await get_tree().create_timer(1.5).timeout
        continue_button.show()
        sad_goblin.show()
        sad_goblin.texture = preload("res://events_gold_dice.png")
        var kamikaze_fail = preload("res://sounds/kamikazefail.mp3")
        audio_listener_2d.stream = kamikaze_fail
        audio_listener_2d.play()
        Global.gold = 0 
        Events.gold_changed.emit()
        

func _on_test_pressed() -> void:
    print("pressed test")
