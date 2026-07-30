extends CardState


func enter() -> void:
    card_ui.drop_point_detector.monitoring = true
    card_ui.original_index = card_ui.get_index()


func on_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        # Refuse at the START of the gesture (STS2-style) rather than on release: the player
        # finds out before committing the whole drag, and because this only fires on motion,
        # a bare click to read the card stays completely silent. Hover-to-inspect is
        # untouched either way - that lives on mouse_entered, not here.
        #
        # Bouncing straight back to BASE also means one refusal per click: BASE only re-enters
        # CLICKED on a fresh button press, so holding and wiggling can't machine-gun the shake.
        if card_ui.is_drag_blocked():
            card_ui.play_pickup_refusal()
            transition_requested.emit(self, CardState.State.BASE)
            return
        transition_requested.emit(self, CardState.State.DRAGGING)
