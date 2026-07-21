extends Card

const UNLUCKY_STATUS = preload("res://statuses/unlucky.tres")

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:


    var status_effect := StatusEffect.new()
    var unlucky := UNLUCKY_STATUS.duplicate()
    unlucky.duration = 1
    status_effect.status = unlucky
    status_effect.execute(targets)
    Global.giant_dice_current_amount+=1
    Events.dice_amount_changed.emit()
    Events.charge_dice_animation.emit()
    Events.temporary_dice_added.emit("giant")
