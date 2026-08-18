extends Control

@onready var convert_dice: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/ConvertDice
@onready var quit: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit
@onready var quit_text: RichTextLabel = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/Quit/QuitText
@onready var event_text: RichTextLabel = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/EventText


# This event EATS a Blue Dice, and since the run-start loadout picker a run can own zero
# Blue (The Elf, The Acrobat). The pool gate (EventStats.required_dice_type = "blue") keeps
# it out of the draw entirely in that case - this is the second layer, so the trade can
# never fire without a Blue to trade even if the event is reached some other way
# (force_for_testing, an old save's pool, a stripped .tres property).
func setup(_character: CharacterStats, _stats: RunStats) -> void:
    convert_dice.visible = Global.blue_dice_max_amount >= 1


func _on_quit_pressed() -> void:
    Events.event_exited.emit()




func _on_convert_dice_pressed() -> void:
    if Global.blue_dice_max_amount < 1:
        return
    Global.blue_dice_max_amount -=1
    Global.blue_dice_current_amount = maxi(0, Global.blue_dice_current_amount - 1)
    # Spending your LAST Blue drops it out of the owned-types list too, so the inventory
    # keeps matching the dice you actually have (it is saved with the run, and the card
    # shop's deal die reads it).
    if Global.blue_dice_max_amount == 0:
        Global.dice_inventory.erase("blue")
    Global.giant_dice_max_amount+=1
    Global.giant_dice_current_amount+=1
    if not Global.dice_inventory.has("giant"):
        Global.dice_inventory.append("giant")
    convert_dice.hide()
    quit_text.text = "[center]Continue[/center]"
    event_text.text = "Your [color=blue][b]Blue Dice[/b][/color] is melting. A [color=green][b]Giant Dice[/b][/color] comes out of the ancient machine. [p] [p]You put it in your pocket."
    Events.update_dice_top_bar.emit()
    Events.dice_price_changed.emit()
