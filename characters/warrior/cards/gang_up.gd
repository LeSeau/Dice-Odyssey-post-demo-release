extends Card

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value == 6:
        Global.blue_dice_current_amount+=4
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.reset_charged_card.emit()
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.card_type_played.emit("exact")

func _on_dice_rolled():
    print("adding dice to damage")
