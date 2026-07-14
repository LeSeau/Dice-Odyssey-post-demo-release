extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    var total_dice = Global.blue_dice_current_amount + Global.red_dice_current_amount + Global.green_dice_current_amount + Global.giant_dice_current_amount + Global.magma_dice_current_amount + Global.even_dice_current_amount + Global.odd_dice_current_amount + Global.mech_dice_current_amount
    
    if total_dice == 0:
        Global.green_dice_current_amount += 3
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit("green")
        Events.card_type_played.emit("support")
    Events.reset_charged_card.emit()
