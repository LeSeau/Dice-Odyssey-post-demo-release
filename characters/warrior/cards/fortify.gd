extends Card

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

func apply_effects(targets: Array [Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return

    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)

    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 2
    status_effect.status = muscle
    status_effect.execute(targets)

    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Gain 2 Strength"
    if not has_active_roll():
        return "Block X. Gain 2 Strength"
    if not meets_requirement():
        return "Block X. Gain 2 Strength"
    return "Block %d. Gain 2 Strength" % Global.roll_value
