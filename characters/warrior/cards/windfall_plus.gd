extends Card

# Windfall+ throws a Blue Dice (d6) instead of a Pixie Dice (d3) - same "draw its roll on
# landing" payoff, bigger swing (up to 6 cards). Own script because the thrown die type is
# hardcoded in the throw. See windfall.gd for the design notes.


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var faces: Array = thrown_faces_for("blue")
    var value: int = faces[randi() % faces.size()]
    Events.dice_thrown.emit([{"type": "blue", "value": value, "target": null}], Global.last_played_card_position)
    if not targets.is_empty():
        var timer := targets[0].get_tree().create_timer(Global.DICE_THROW_FLIGHT_TIME, false)
        timer.timeout.connect(_on_windfall_landed.bind(value))
    Events.reset_charged_card.emit()


func _on_windfall_landed(value: int) -> void:
    Global.report_thrown_die_landed("blue", value)
    if value > 0:
        Events.draw_card.emit(value)
