extends Control

@onready var convert_dice: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/ConvertDice
@onready var quit: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit
@onready var quit_text: RichTextLabel = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit/QuitText
@onready var event_text: RichTextLabel = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/EventText

func _on_quit_pressed() -> void:
    Events.event_exited.emit()




func _on_convert_dice_pressed() -> void:
    Global.blue_dice_max_amount -=1
    Global.giant_dice_max_amount+=1
    Global.giant_dice_current_amount+=1
    convert_dice.hide()
    quit_text.text = "[center]Continue[/center]"
    event_text.text = "Your [color=blue][b]Blue Dice[/b][/color] is melting. A [color=green][b]Giant Dice[/b][/color] comes out of the ancient machine. [p] [p]You put it in your pocket."
    Events.update_dice_top_bar.emit()
    Events.dice_price_changed.emit()
