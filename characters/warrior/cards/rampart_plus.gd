extends Card

# Rampart+ throws TWO Odd Dice (1/3/5/7) instead of one Even Dice - each adds ITS roll as
# more Block when it lands, sequenced by the shared volley stagger so each landing punch
# stays legible. Gain X Block still applies immediately. Own script because count + die type
# live in the throw. Thrown-die ruling: raw roll, no modifiers.

const THROW_COUNT := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    var player: Node = targets[0] if not targets.is_empty() else null
    var faces: Array = thrown_faces_for("odd")
    var throws: Array = []
    var stagger := Global.dice_throw_volley_stagger(THROW_COUNT)
    for i in THROW_COUNT:
        var value: int = faces[randi() % faces.size()]
        throws.append({"type": "odd", "value": value, "target": null})
        if player != null:
            var timer := player.get_tree().create_timer(Global.DICE_THROW_FLIGHT_TIME + stagger * i, false)
            timer.timeout.connect(_on_rampart_landed.bind(player, value))
    Events.dice_thrown.emit(throws, Global.last_played_card_position)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func _on_rampart_landed(player: Node, value: int) -> void:
    # Counts as a rolled die even if the player node is gone (fight over) - the die landed.
    Global.report_thrown_die_landed("odd", value)
    if player == null or not is_instance_valid(player):
        return
    var block_effect := BlockEffect.new()
    block_effect.amount = value
    block_effect.sound = sound
    block_effect.execute([player])


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Throw 2 Odd Dice that Block their roll"
    if not has_active_roll():
        return "Gain X Block. Throw 2 Odd Dice that Block their roll"
    return "Gain X Block (%d). Throw 2 Odd Dice that Block their roll" % Global.roll_value
