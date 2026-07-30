extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value + 3
    block_effect.sound = sound
    block_effect.execute(targets)
    Events.dice_roll_reset.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Gain ? Block"
    if not has_active_roll():
        return "Gain X+3 Block"
    return "Gain X+3 Block (%d)" % (Global.roll_value + 3)
