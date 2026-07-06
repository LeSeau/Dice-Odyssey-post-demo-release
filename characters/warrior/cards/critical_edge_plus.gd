extends Card

const CRITICAL_EDGE_PLUS_STATUS = preload("res://statuses/status_critical_edge_plus.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value >= 6:
        var status_effect := StatusEffect.new()
        var critical_edge := CRITICAL_EDGE_PLUS_STATUS.duplicate()
        status_effect.status = critical_edge
        status_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
