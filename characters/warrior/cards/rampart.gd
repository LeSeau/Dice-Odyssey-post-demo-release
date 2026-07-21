extends Card

# Block X now, then the thrown Even Dice adds ITS roll as more Block when it lands
# (2/4/6/8 - always pays something). Thrown-die ruling: raw roll, no modifiers. Block
# cards use Global.roll_value raw per the established convention (no DMG modifier).


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    var faces: Array = DICE_FACE_VALUES["even"]
    var value: int = faces[randi() % faces.size()]
    Events.dice_thrown.emit([{"type": "even", "value": value, "target": null}], Global.last_played_card_position)
    if not targets.is_empty():
        var timer := targets[0].get_tree().create_timer(Global.DICE_THROW_FLIGHT_TIME, false)
        timer.timeout.connect(_on_rampart_landed.bind(targets[0], value))
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func _on_rampart_landed(player: Node, value: int) -> void:
    if player == null or not is_instance_valid(player):
        return
    var block_effect := BlockEffect.new()
    block_effect.amount = value
    block_effect.sound = sound
    block_effect.execute([player])


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Throw an Even Dice that Blocks its roll"
    if not has_active_roll():
        return "Block X. Throw an Even Dice that Blocks its roll"
    return "Block %d. Throw an Even Dice that Blocks its roll" % Global.roll_value
