class_name EclipseStatus
extends Status

func initialize_status(_target: Node) -> void:
    # Connect to the dice roll reset event to consume the status
    if not Events.dice_roll_reset.is_connected(consume_eclipse):
        Events.dice_roll_reset.connect(consume_eclipse)

func consume_eclipse() -> void:
    # Check if we should skip this consumption due to Global.no_reset
    if Global.no_reset:
        return
    
    # Reduce duration by 1
    if duration > 0:
        duration -= 1
    
    print("Eclipse status consumed, remaining duration: ", duration)
    
    # The status_changed signal will trigger status_ui to update or remove itself
    status_changed.emit()

func apply_status(target: Node) -> void:
    print("Eclipse status applied")
    
    # Your current eclipse logic here
    if type == Status.Type.START_OF_TURN and target is Player:
        print("Eclipse: Drawing extra card")
        Events.draw_card.emit(1)
    
    status_applied.emit(self)
