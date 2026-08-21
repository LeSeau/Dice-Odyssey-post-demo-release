extends Relic

func initialize_relic(owner: RelicUI) -> void:
    Events.card_played.connect(_on_card_played)



func _on_card_played(card: Card):
    if Global.cards_played_this_turn == 3:
        var active_dice = Global.dice_type
        var dice_amount_variable = active_dice + "_dice_current_amount"
        
        # Check if the variable exists in Global
        if dice_amount_variable in Global:
            # Update the corresponding amount dynamically
            var current_amount = Global.get(dice_amount_variable)
            Global.set(dice_amount_variable, current_amount + 1)
            Events.dice_amount_changed.emit()
            Events.dice_charged.emit(active_dice, 1)
