extends Button
@onready var dice: Dice = $".."


func _on_pressed() -> void:
    print("roll pressed")
    dice.roll_dice()
