extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    Events.reset_charged_card.emit()
    if meets_requirement():
        Global.magma_dice_current_amount+=2
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit("magma")


func _on_dice_rolled():
    print("adding dice to damage")
