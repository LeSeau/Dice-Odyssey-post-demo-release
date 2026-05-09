extends Card

const MARIONETTE_STATUS = preload("res://statuses/status_marionette.tres")


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6:
        var status_effect := StatusEffect.new()
        var marionette := MARIONETTE_STATUS.duplicate()
        status_effect.status = marionette
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
