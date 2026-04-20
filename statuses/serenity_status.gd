class_name SerenityStatus
extends Status

func apply_status(target: Node) -> void:
    print("Serenity applied - will draw extra card at start of turn")
    
    # Only affect card draw if this is a START_OF_TURN application and target is player
    if type == Status.Type.START_OF_TURN and target is Player:
        print("Serenity: Adding 1 to cards per turn")
        # Instead of immediately drawing, modify the player's cards_per_turn
        Events.draw_card.emit(1)
    
    status_applied.emit(self)
