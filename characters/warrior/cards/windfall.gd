extends Card

# Toss a conjured Pixie Dice (d3): when it LANDS you draw that many cards (delayed to the
# landing so the tumbling die stays honest - no number spoiler while it's in the air).
# SUPPORT flag + no reset by construction: it's a card-advantage setup card, it doesn't
# consume Power so it never resets it. The landed value is NOT appended to roll_history
# (it isn't a die from your pool - Recombobulate shouldn't refund it), but it DOES count
# as a rolled die via report_thrown_die_landed (counters + opt-in triggers).


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var faces: Array = thrown_faces_for("green")
    var value: int = faces[randi() % faces.size()]
    Events.dice_thrown.emit([{"type": "green", "value": value, "target": null}], Global.last_played_card_position)
    if not targets.is_empty():
        var timer := targets[0].get_tree().create_timer(Global.DICE_THROW_FLIGHT_TIME, false)
        timer.timeout.connect(_on_windfall_landed.bind(value))
    Events.reset_charged_card.emit()


func _on_windfall_landed(value: int) -> void:
    # Counts as a rolled die (counters + opt-in triggers) - still stays out of
    # roll_history, see the header comment.
    Global.report_thrown_die_landed("green", value)
    if value > 0:
        Events.draw_card.emit(value)
