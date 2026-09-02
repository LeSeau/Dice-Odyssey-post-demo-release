extends Control

@onready var roll_golden_dice: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/RollGoldenDice
@onready var quit: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit
@onready var dice_panel: Panel = $DicePanel
@onready var roll_dice: Button = $DicePanel/DiceDisplay/RollDice
@onready var dice_display: TextureRect = $DicePanel/DiceDisplay
@onready var reward_panel: Panel = $DicePanel/RewardPanel
@onready var continue_button: Button = $DicePanel/ContinueButton
@onready var reward_label: RichTextLabel = $DicePanel/RewardPanel/RewardLabel

@onready var sad_goblin: TextureRect = $DicePanel/SadGoblin
@onready var audio_listener_2d: AudioStreamPlayer2D = $AudioListener2D

const MODAL_TEXT := preload("res://scenes/events/event_modal_text.gd")

# Payout is roll x GOLD_PER_PIP; a 1 costs a FLAT GOLD_LOST_ON_ONE instead of the
# whole purse. The old proportional wipe meant the player set their own risk -
# taking the event straight after a shop was free money - so the payout was the
# only thing scaling, never the cost.
const GOLD_PER_PIP := 15
const GOLD_LOST_ON_ONE := 50


func _ready() -> void:
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



func _on_quit_pressed() -> void:
    Events.event_exited.emit()

func _on_continue_button_pressed() -> void:
    Events.event_exited.emit()

func _on_roll_golden_dice_pressed() -> void:
    print("opening golden dice box")
    dice_panel.show()


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
        roll_dice.hide()
        reward_panel.show()
        var gold_reward = roll_result * GOLD_PER_PIP
        Global.gold += gold_reward 
        Events.gold_changed.emit()

        # 🔥 Build the reward text manually
        reward_label.text = "[center]You won [color=gold]" + str(gold_reward) + " Gold[/color]![/center]"
        MODAL_TEXT.center_label(reward_label)

        # Step 4: Wait another 1.5 seconds, show sad goblin
        await get_tree().create_timer(1.5).timeout
        continue_button.show()
        sad_goblin.show()
        var kamikaze_fail = preload("res://sounds/kamikazefail.mp3")
        audio_listener_2d.stream = kamikaze_fail
        audio_listener_2d.play()
    else:
        roll_dice.hide()
        reward_panel.show()
        # Report what he actually took, which is less than 50 on a thin purse.
        var gold_lost: int = mini(GOLD_LOST_ON_ONE, Global.gold)
        Global.gold -= gold_lost
        Events.gold_changed.emit()
        reward_label.text = "[center]\"Thank you!\" [color=#e05a5a]-" + str(gold_lost) + " Gold[/color][/center]"
        MODAL_TEXT.center_label(reward_label)
        await get_tree().create_timer(1.5).timeout
        continue_button.show()
        sad_goblin.show()
        sad_goblin.texture = preload("res://events_gold_dice.png")
        var kamikaze_fail = preload("res://sounds/kamikazefail.mp3")
        audio_listener_2d.stream = kamikaze_fail
        audio_listener_2d.play()

