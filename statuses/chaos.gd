class_name ChaosStatus
extends Status

const MODIFIER := 0.5

# In weak.gd
func initialize_status(target: Node) -> void:
    if not Events.check_chaos_status.is_connected(consume_stack):
        Events.check_chaos_status.connect(consume_stack)

func consume_stack() -> void:
    if duration > 0:
        print("consuming stack")
        Events.discard_random_card.emit()
        
        # Create a callback for the delayed draw card event
        var delayed_draw = func():
            Events.draw_card.emit(1)
        
        # Create a timer for the delay
        var timer = Timer.new()
        timer.one_shot = true
        timer.wait_time = 1.0  # 1 second delay
        timer.timeout.connect(delayed_draw)
        timer.timeout.connect(func(): timer.queue_free())  # Self-cleanup
        
        # Add to scene tree - assuming we can access the main scene through a global
        if Engine.get_main_loop().current_scene:
            Engine.get_main_loop().current_scene.add_child(timer)
            timer.start()
        
        # The status_changed signal will trigger status_ui to update or remove itself
        status_changed.emit()

func apply_status(target: Node) -> void:
    status_applied.emit(self)
