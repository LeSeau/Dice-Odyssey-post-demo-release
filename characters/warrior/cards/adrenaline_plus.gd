extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Global.red_dice_current_amount += 3
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.reset_charged_card.emit()
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit("red", 3)
    Events.temporary_dice_added.emit("red")
