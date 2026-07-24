extends Card

# Throw a Pixie Dice (d3): when it LANDS, gain its roll as Strength (Muscle) for the rest
# of the fight. Delayed to the landing like every thrown die. SUPPORT flag + no reset: it's
# a setup card, it doesn't consume Power. The landed die counts as a rolled die (counters +
# opt-in triggers) but stays out of roll_history / the Power chain.

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var faces: Array = thrown_faces_for("green")
    var value: int = faces[randi() % faces.size()]
    Events.dice_thrown.emit([{"type": "green", "value": value, "target": null}], Global.last_played_card_position)
    if not targets.is_empty():
        var timer := targets[0].get_tree().create_timer(Global.DICE_THROW_FLIGHT_TIME, false)
        timer.timeout.connect(_on_kickstart_landed.bind(targets[0], value))
    Events.reset_charged_card.emit()


func _on_kickstart_landed(player: Node, value: int) -> void:
    Global.report_thrown_die_landed("green", value)
    if player == null or not is_instance_valid(player) or value <= 0:
        return
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = value
    status_effect.status = muscle
    status_effect.execute([player])
