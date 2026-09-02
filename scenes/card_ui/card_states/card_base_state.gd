extends CardState


func enter() -> void:
    if not card_ui.is_node_ready():
        await card_ui.ready

    if card_ui.tween and card_ui.tween.is_running():
        card_ui.tween.kill()

    #card_ui.panel.set("theme_override_styles/panel", card_ui.BASE_STYLEBOX)
    card_ui.reparent_requested.emit(card_ui)
    card_ui.pivot_offset = Vector2.ZERO
    Events.fan_hand_requested.emit()
    card_ui.reapply_playable_visual()
    #Events.tooltip_hide_requested.emit()


func on_gui_input(event: InputEvent) -> void:
    if not card_ui.playable or card_ui.disabled:
        return

    if event.is_action_pressed("left_mouse"):
        card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
        transition_requested.emit(self, CardState.State.CLICKED)


func on_mouse_entered() -> void:
    #if not card_ui.playable or card_ui.disabled:
        #return

    card_ui.panel.set("theme_override_styles/panel", card_ui.HOVER_STYLEBOX)
    if card_ui.card.type == Card.Type.OMEN:
        card_ui.card_frame.add_theme_stylebox_override("panel", card_ui.OMEN_STYLEBOX)
    elif card_ui.card.can_play_without_dice:
        card_ui.panel.set("theme_override_styles/panel", card_ui.HOVER_CELESTIAL_STYLEBOX)
        card_ui.card_frame.add_theme_stylebox_override("panel", card_ui.SUPPORT_STYLEBOX)
    elif card_ui.card.type == Card.Type.BLESSING:
        card_ui.card_frame.add_theme_stylebox_override("panel", card_ui.BLESSING_STYLEBOX)
    card_ui.reapply_playable_visual()
    #Events.card_tooltip_requested.emit(card_ui.card.icon, card_ui.card.tooltip_text)


func on_mouse_exited() -> void:
    if not card_ui.playable or card_ui.disabled:
        return
    if card_ui.card.type == Card.Type.OMEN:
        card_ui.card_frame.add_theme_stylebox_override("panel", card_ui.OMEN_STYLEBOX)
    elif card_ui.card.can_play_without_dice:
        card_ui.panel.set("theme_override_styles/panel", card_ui.BASE_CELESTIAL_STYLEBOX)
        card_ui.card_frame.add_theme_stylebox_override("panel", card_ui.SUPPORT_STYLEBOX)
    elif card_ui.card.type == Card.Type.BLESSING:
        card_ui.card_frame.add_theme_stylebox_override("panel", card_ui.BLESSING_STYLEBOX)
    else:
        card_ui.panel.set("theme_override_styles/panel", card_ui.BASE_STYLEBOX)
    card_ui.reapply_playable_visual()
