extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if meets_requirement():
        Global.blue_dice_current_amount+=5
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.reset_charged_card.emit()
        Events.dice_amount_changed.emit()
        Events.dice_charged.emit("blue", 5)
        Events.card_type_played.emit("exact")

func _on_dice_rolled():
    print("adding dice to damage")
