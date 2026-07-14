extends Card
func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value == 6:
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Global.even_dice_current_amount+=2
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit("even")
        # Add Oracle card to hand

        # load() is still ResourceLoader-cached by path - duplicate so a repeat trigger never
        # hands out the SAME Card object twice (see calculations.gd for the full rationale).
        var oracle_card = load("res://characters/warrior/cards/card_scout5.tres").duplicate()
        Events.add_card_to_hand_requested.emit(oracle_card)
        Events.dice_roll_reset.emit()
        Events.reset_charged_card.emit()
        Events.card_type_played.emit("exact")

func _on_dice_rolled():
    print("adding dice to damage")
