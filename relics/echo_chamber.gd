extends Relic

func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))

func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    var h: Array = Global.roll_history
    if h.size() < 2 or h[h.size() - 1] != h[h.size() - 2]:
        return
    owner.flash()
    Global.blue_dice_current_amount += 1
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit("blue", 1)
    Events.temporary_dice_added.emit("blue")

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
