extends Card

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    Global.giant_dice_current_amount+=1
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit("giant", 1)
    Events.temporary_dice_added.emit("giant")
