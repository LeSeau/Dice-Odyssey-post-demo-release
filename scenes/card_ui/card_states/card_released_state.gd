extends CardState
var played: bool

func enter() -> void:
    Global.dragging_card = false
    print("entering released state")
    Events.fan_hand_requested.emit()
    played = false
    
    if Global.playing_red_card: 
        # We're PLAYING a socketed card (rolling dice with it)
        if card_ui.card.target == Card.Target.SINGLE_ENEMY:
            if card_ui.targets.is_empty():
                print("No target for single enemy card, returning to AIMING")
                transition_requested.emit(self, CardState.State.AIMING)
                return
            
            played = true
            card_ui.play()
            Global.playing_red_card = false
            queue_free()
            Events.reset_charged_card.emit()
        else:
            card_ui.play()
            Global.playing_red_card = false
            queue_free()
            Events.reset_charged_card.emit()
    else:
        # We're on red dice but NOT currently playing
        if Global.dice_type == "red":
            if card_ui.card.can_play_without_dice:
                print("Card can be played without dice, playing directly")
                played = true
                card_ui.play()
                queue_free()
                Events.reset_charged_card.emit()
            else:
                # SOCKETING a card (not playing yet)
                Events.card_charged.emit(card_ui)
                # DON'T set Global.playing_red_card here
                # It should only be set when actually rolling dice with the card
        
        if Global.dice_type == "red":
            print("current dice is red")
            Global.charged_card_instance_id = card_ui.card.instance_id
    

            
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
