extends Card

# Gain X Block now, then the thrown Blue Dice adds ITS roll as more Block when it lands
# (1-6). Thrown-die ruling: raw roll, no modifiers. Block
# cards use Global.roll_value raw per the established convention (no DMG modifier).


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    var faces: Array = thrown_faces_for("blue")
    var value: int = faces[randi() % faces.size()]
    Events.dice_thrown.emit([{"type": "blue", "value": value, "target": null}], Global.last_played_card_position)
    if not targets.is_empty():
        var timer := targets[0].get_tree().create_timer(Global.DICE_THROW_FLIGHT_TIME, false)
        timer.timeout.connect(_on_rampart_landed.bind(targets[0], value))
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func _on_rampart_landed(player: Node, value: int) -> void:
    # Counts as a rolled die even if the player node is gone (fight over) - the die landed.
    Global.report_thrown_die_landed("blue", value)
    if player == null or not is_instance_valid(player):
        return
    var block_effect := BlockEffect.new()
    block_effect.amount = value
    block_effect.sound = sound
    block_effect.execute([player])


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Gain ? Block. Throw a Blue Dice that grants Block equal to its roll"
    if not has_active_roll():
        return "Gain X Block. Throw a Blue Dice that grants Block equal to its roll"
    return "Gain X Block (%d). Throw a Blue Dice that grants Block equal to its roll" % Global.roll_value
