extends TextureRect

func _on_Dice_input_event(viewport, event, shape_idx):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        print("Dice clicked!")
        # Handle dice click here
