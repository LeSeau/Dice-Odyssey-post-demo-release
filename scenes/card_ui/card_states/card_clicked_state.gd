extends CardState


func enter() -> void:
    card_ui.drop_point_detector.monitoring = true
    card_ui.original_index = card_ui.get_index()


func on_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        # BASE checks `disabled` on the button PRESS; the promotion to DRAGGING happens frames
        # later on the first motion, so re-check here or a gate that tightened in between (the
        # tutorial re-gates on every step change) would still let the drag start. Silent bounce
        # rather than play_pickup_refusal(): a card the tutorial has locked isn't the player
        # misreading a requirement, so it gets no shake/error sound.
        if card_ui.disabled:
            transition_requested.emit(self, CardState.State.BASE)
            return
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
