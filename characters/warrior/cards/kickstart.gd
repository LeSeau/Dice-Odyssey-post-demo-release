extends Card

# Throw an Odd Dice (1/3/5/7): when it lands, Boost its roll - your next roll gets that
# much added (same next_roll_modifier channel as Dynamite/Finesse/Steady Hand). Delayed
# to the landing like every thrown die. SUPPORT flag + no reset: it's a setup card.


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var faces: Array = thrown_faces_for("odd")
    var value: int = faces[randi() % faces.size()]
    Events.dice_thrown.emit([{"type": "odd", "value": value, "target": null}], Global.last_played_card_position)
    if not targets.is_empty():
        var timer := targets[0].get_tree().create_timer(Global.DICE_THROW_FLIGHT_TIME, false)
        timer.timeout.connect(_on_kickstart_landed.bind(value))
    Events.reset_charged_card.emit()


func _on_kickstart_landed(value: int) -> void:
    # Counts as a rolled die (counters + opt-in triggers like Hardened Grip/Snake Eyes).
    Global.report_thrown_die_landed("odd", value)
    Global.next_roll_modifier += value
    Events.display_next_roll_modifier.emit()
