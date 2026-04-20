extends Card
func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void: 
    if Global.roll_value == 6:
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.draw_card.emit(2)
        
        # Add Oracle card to hand

        var oracle_card = load("res://characters/warrior/cards/card_oracle_exhaust.tres")
        Events.add_card_to_hand_requested.emit(oracle_card)
        Events.dice_roll_reset.emit()
        Events.reset_charged_card.emit()    
        Events.card_type_played.emit("exact")

func _on_dice_rolled():
    print("adding dice to damage")
