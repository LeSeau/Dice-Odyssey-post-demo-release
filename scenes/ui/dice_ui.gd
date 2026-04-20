extends Control

@onready var dice_ui: Control = $"."
@onready var dice_texture: TextureRect = $DiceTexture
@onready var dice_label: Label = $DiceLabel

var evil_dice_data: DiceData

var data: DiceData

var show_label: bool = true

func _ready():
    # Create the Evil Dice data
    evil_dice_data = DiceData.new()
    evil_dice_data.name = "Evil Dice"
    evil_dice_data.possible_rolls = [6,6,6,0]
    evil_dice_data.texture = preload("res://assets/images/evil6.png")  # Set texture to your Evil Dice texture
    
    # Call the setup function to apply the Evil Dice to the UI
    dice_ui.setup(evil_dice_data, true)  # Pass true if you want to show the label

func setup(dice_data: DiceData, show_label := true):
    data = dice_data
    self.show_label = show_label
    
    dice_texture.texture = data.texture
    
    if show_label:
        dice_label.text = "0 / 1"  # Or whatever current/max you track
        dice_label.show()
    else:
        dice_label.hide()
