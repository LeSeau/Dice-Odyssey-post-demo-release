extends Card

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value < 10:
        return
    Events.reset_charged_card.emit()
    var status_effect := StatusEffect.new()
    var exposed := EXPOSED_STATUS.duplicate()
    exposed.duration = 2
    status_effect.status = exposed
    status_effect.execute(targets)
    Events.add_block.emit(Global.roll_value)
    Events.dice_roll_reset.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Apply Exposed 2 to ALL enemies and gain ? Block"
    if not has_active_roll() or not meets_requirement():
        return "Apply Exposed 2 to ALL enemies and gain X Block"
    return "Apply Exposed 2 to ALL enemies and gain X Block (%d)" % Global.roll_value
