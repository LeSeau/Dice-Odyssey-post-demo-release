# DiceData.gd
extends Resource
class_name DiceData

@export var name: String
@export var texture: Texture
@export var possible_rolls: Array = []
@export var min_roll: int = 1
@export var max_roll: int = 6
@export var color: Color = Color.WHITE
@export var type: String = "blue"  # or use enum later
@export var description: String = ""
@export var special_effect: String = ""

# Add current_amount and max_amount
@export var current_amount: int = 0
@export var max_amount: int = 0
