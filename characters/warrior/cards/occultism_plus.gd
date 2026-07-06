extends Card

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    Global.giant_dice_current_amount+=1
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
    Events.charge_dice_animation.emit()
    Events.temporary_dice_added.emit("giant")
