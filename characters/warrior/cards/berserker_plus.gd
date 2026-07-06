extends Card
const BERSERK_STATUS = preload("res://statuses/status_berserk.tres")


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 4:
        var status_effect := StatusEffect.new()
        var berserk := BERSERK_STATUS.duplicate()
        status_effect.status = berserk
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
