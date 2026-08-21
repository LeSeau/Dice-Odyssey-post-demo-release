extends CardState
var played: bool

func enter() -> void:
    Global.dragging_card = false
    Events.fan_hand_requested.emit()
    played = false
    
    if Global.playing_red_card:
        # We're PLAYING a socketed card (rolling dice with it)
        if card_ui.card.target == Card.Target.SINGLE_ENEMY:
            if card_ui.targets.is_empty():
                transition_requested.emit(self, CardState.State.AIMING)
                return

            played = true
            card_ui.play()
            # Emit BEFORE clearing playing_red_card: dice.gd's _on_reset_charged_card only
            # takes its "socketed card was actually played" branch (fly the socket display
            # to discard + drop socketed_card_ui) while the flag is still true. The old
            # order cleared the flag first, so a card whose apply_effects never emits
            # reset_charged_card itself (e.g. Low Blow whiffing its Max requirement = a
            # full no-op) left dice.gd pointing at the played CardUI; End Turn's
            # clear_socket then "canceled" the already-played card back into the hand,
            # where the end-of-turn discard added it to the discard pile a SECOND time -
            # the same Card object twice in the pile = duplicate copies drawn next shuffle.
            Events.reset_charged_card.emit()
            Global.playing_red_card = false
            queue_free()
        else:
            card_ui.play()
            Events.reset_charged_card.emit()
            Global.playing_red_card = false
            queue_free()
    else:
        # We're on red dice but NOT currently playing
        if Global.dice_type == "red":
            if card_ui.card.can_play_without_dice:
                # Celestial cards never socket - they play directly even on red. But a
                # single-targeted one (e.g. Slash) still needs a target: playing it with
                # an empty targets array would just discard it with zero effect, so route
                # it through AIMING exactly like the non-red flow does.
                if card_ui.card.is_single_targeted() and card_ui.targets.is_empty():
                    transition_requested.emit(self, CardState.State.AIMING)
                    return
                played = true
                card_ui.play()
                queue_free()
                Events.reset_charged_card.emit()
                # This card was PLAYED, not socketed - don't fall through to the
                # charged_card_instance_id assignment below, which would overwrite the id
                # of a card legitimately sitting in the socket (its red roll would then
                # fail the instance_id match and never play).
                return
            else:
                # SOCKETING a card (not playing yet)
                Events.card_charged.emit(card_ui)
                # DON'T set Global.playing_red_card here
                # It should only be set when actually rolling dice with the card

        if Global.dice_type == "red":
            Global.charged_card_instance_id = card_ui.card.instance_id
            # Append rather than replace: with a second socket open, BOTH socketed cards
            # have to fire on the one Red roll. dice.gd prunes this list whenever a
            # socket is emptied.
            if not Global.charged_card_instance_ids.has(card_ui.card.instance_id):
                Global.charged_card_instance_ids.append(card_ui.card.instance_id)


            
        elif not card_ui.targets.is_empty():
            if not (Global.dice_type != "red" and card_ui.card.red_only==true):
                # roll_value > 0 alone wrongly blocks a legit play when the active dice's
                # last roll genuinely happened but resolved to 0 (Evil dice's crack face) -
                # has_active_roll() (roll_history not empty) distinguishes "rolled and got
                # unlucky" from "haven't rolled yet", so cards like Recombobulate can still
                # be played as the safety valve they're meant to be even on a crack roll.
                if Global.roll_value > 0 or card_ui.card.has_active_roll() or card_ui.card.can_play_without_dice:
                    played = true
                    card_ui.play()
                    Events.reset_charged_card.emit()
                    Global.playing_red_card = false
            
func on_input(_event: InputEvent) -> void:
    if played:
        return
    
    if Global.playing_red_card and card_ui.card.target == Card.Target.SINGLE_ENEMY and card_ui.targets.is_empty():
        transition_requested.emit(self, CardState.State.AIMING)
        return
    Events.fan_hand_requested.emit()
    transition_requested.emit(self, CardState.State.BASE)
