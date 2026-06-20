extends CardState

const DRAG_MINIMUM_THRESHOLD := 0.05

var minimum_drag_time_elapsed := false


func enter() -> void:
    Global.dragging_card = true
    var ui_layer := get_tree().get_first_node_in_group("ui_layer")
    if ui_layer:
        # Store the exact global position before reparenting
        var mouse_pos = card_ui.get_global_mouse_position()
        
        # Reparent to UI layer
        card_ui.reparent(ui_layer) 
        
        # Reset any rotation from the fan effect
        card_ui.rotation = 0
        
        # Position card centered on mouse
        card_ui.global_position = mouse_pos - (card_ui.size / 2)
    
    if card_ui.card.can_play_without_dice:
        card_ui.panel.set("theme_override_styles/panel", card_ui.DRAG_CELESTIAL_STYLEBOX)
        card_ui.card_frame.add_theme_stylebox_override("panel", card_ui.SUPPORT_STYLEBOX)
    else:
        card_ui.panel.set("theme_override_styles/panel", card_ui.DRAG_STYLEBOX)
    Events.card_drag_started.emit(card_ui)
    
    minimum_drag_time_elapsed = false
    var threshold_timer := get_tree().create_timer(DRAG_MINIMUM_THRESHOLD, false)
    threshold_timer.timeout.connect(func(): minimum_drag_time_elapsed = true)
    Events.fan_hand_requested.emit()

func exit() -> void:
    
    Events.card_drag_ended.emit(card_ui)
    Events.fan_hand_requested.emit()
#

func on_input(event: InputEvent) -> void:
    var single_targeted := card_ui.card.is_single_targeted()
    var mouse_motion := event is InputEventMouseMotion
    var cancel = event.is_action_pressed("right_mouse")
    var confirm = event.is_action_released("left_mouse") or event.is_action_pressed("left_mouse")
    
    # Transition to AIMING on mouse motion (existing behavior)
    if single_targeted and mouse_motion and card_ui.targets.size() > 0 and Global.dice_type != "red":
        transition_requested.emit(self, CardState.State.AIMING)
        return
    
    if mouse_motion:
        card_ui.global_position = get_viewport().get_mouse_position() - (card_ui.size / 2)
        Events.fan_hand_requested.emit()
    
    if cancel:
        transition_requested.emit(self, CardState.State.BASE)
    elif minimum_drag_time_elapsed and confirm:
        get_viewport().set_input_as_handled()
        # If it's a single-targeted card and not red dice, go to AIMING instead of RELEASED
        if single_targeted and Global.dice_type != "red":
            transition_requested.emit(self, CardState.State.AIMING)
        else:
            transition_requested.emit(self, CardState.State.RELEASED)
